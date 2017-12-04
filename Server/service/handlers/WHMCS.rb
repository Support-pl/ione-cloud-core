# Очередь выполнения для методов
# На каждый метод, создается ключ(прим. thread_locks[:NewAccount]) под которым есть массив объектов класса MethodThread
# Этот массив реализует очередь выполнения
$thread_locks = Hash.new { |hash, key| hash[key] = Array.new }
# ThreadKiller
# Завершает потоки, время выполнения которых превышает таймаут и которые были запущены
Thread.new do
    while true do
        $thread_locks.each_value do |value|
            Thread.kill(value[0].thread) && LOG("#{value[0].method} thread killed(ID: #{value[0].id})", 'ThreadKiller') && value.delete_at(0) if (value[0].timeout? && value[0].active?)
            value[0].kill_if_wait if !value.nil?
        end
        sleep(3)
    end
end

class WHMHandler
    def initialize(client)
        @client = client
    end
    def Test(msg) # Очень важный метод, по нему WHMCS проверяет доступность сервиса
        LOG "Test message received, text: #{msg}", "Test"
        if msg == "PING" then
            return "PONG"
        end
        return "DONE"
    end

=begin
    Входные данные для NewAccount {
        'login' => '%Логин для нового аккаунта в OpenNebula | строка(String) %',
        'password' => '%Пароль для нового аккаунта | строка(String) %',
        'passwd' => '%Пароль для новой VM | строка(String) %'
        'templateid' => %ID шаблона, из которого будет создана машина | число(Integer::Fixnum)%,
        'groupid' => %ID secondary-группы поользователя по его тарифу | число(Integer::Fixnum)%,
        'release' => %Параметр определяющий будет ли размещаться машина на кластере | логическая переменная(Bool)%,
        'trial' => %Параметр определяющий является ли машина триальной | логическая переменная(Bool)%,
        'ansible' => %Параметр определяющий будут ли запущены какие-либо ансибл скрипты | логическая переменная(Bool)%,
        'ansible-args' => { -- % Если предыдущий параметр(ansible) равен True, то в этом хеше указываются требуемые для установки парметры%
            'service' => '%Задает имя сервиса, который будет установлен => ex. vesta, bitrix-env, zabbix, etc. | строка(String) %',
            ...
            %Другие параметры в зависимости от сервиса%
        },
        'release' => %Параметр определяет нужно ли создавать машину на диске, или только ее прототип | логическая переменная(Bool)%
    }
=end
    def NewAccount(params)
        # LOG params.inspect, "NewAccount"
        # return {'userid' => 666, 'vmid' => 666, 'ip' => '0.0.0.0'}        
        LOG "New Account for #{params['login']} Order Accepted! #{params['trial'] == true ? "VM is Trial" : nil}", "NewAccount"
        LOG "Params: #{params.inspect}", 'NewAccount' if DEBUG
        LOG "Error: TemplateLoadError", 'NewAccount' if params['templateid'].nil?
        return {'error' => "TemplateLoadError"} if params['templateid'].nil?
        LOG "Creating new user for #{params['login']}", "NewAccount"
        userid = UserCreate(params['login'], params['password'], params['groupid'].to_i, @client) if params['test'].nil?
        LOG "Error: UserAllocateError" if userid == 0
        return {'error' => "UserAllocateError"} if userid == 0
        LOG "Creating VM for #{params['login']}", "NewAccount"
        vmid = VMCreate(userid, params['login'], params['templateid'].to_i, params['passwd'], @client, params['release']) if params['test'].nil?
        #TrialController
        if params['trial'] then
            LOG "VM #{vmid} will be suspended in 4 hours", 'NewAccount -> TrialController'
            Thread.new do # Отделение потока с ожидаением и приостановлением машины+пользователя от основного
                sleep(TRIAL_SUSPEND_DELAY)
                Suspend({'userid' => userid, 'vmid' => vmid}, false)
                LOG "TrialVM ##{vmid} suspended", 'NewAccount -> TrialController'
            end
        end
        #endTrialController
        #AnsibleController
        if params['ansible'] && params['release'] then
            Thread.new do
                until STATE(vmid) == 3 && LCM_STATE(vmid) == 3 do
                    sleep(15)
                end
                sleep(60)
                AnsibleController(params.merge({'super' => "NewAccount ->", 'ip' => GetIP(vmid), 'vmid' => vmid}))
            end
            LOG "Install-thread started, you should wait until the #{params['ansible-service']} will be installed", 'NewAccount -> AnsibleController'
        end
        #endAnsibleController
        LOG "New User account and vm created", "NewAccount"
        return {'userid' => userid, 'vmid' => vmid, 'ip' => GetIP(vmid)}
    end
    def Reinstall(params)
        # Сделать проверку на корректность присланных данных: существует ли юзер, существует ли ВМ
        LOG params.inspect, 'DEBUG' if DEBUG
        # return if DEBUG
        LOG "Reinstalling VM#{params['vmid']}", 'Reinstall'

        params['vmid'], params['groupid'], params['userid'], params['templateid'] = params['vmid'].to_i, params['groupid'].to_i, params['userid'].to_i, params['templateid'].to_i

        if params['vmid'] * params['groupid'] * params['userid'] * params['templateid'] == 0 then
            LOG "ReinstallError - some params are nil", 'Reinstall'
            return "ReinstallError - some params are nil"
        end

        obj, id = MethodThread.new(:method => __method__).with_id
        $thread_locks[:reinstall] << obj.thread_obj(Thread.current)
        until $thread_locks[:reinstall][0].id == id || $thread_locks[:reinstall].empty? do
            sleep(5)
        end
        $thread_locks[:reinstall][0].start

        ip, vm = GetIP(params['vmid']), get_pool_element(VirtualMachine, params['vmid'], @client)
        vm_xml = Nori.new.parse(vm.info! || vm.to_xml)
        vm.terminate(true)
        while STATE_STR(params['vmid']) != 'DONE' do
            sleep(1)
        end

        old_template = get_pool_element(Template, params['templateid'], @client)
        old_template = (old_template.info! || old_template.to_hash)['VMTEMPLATE']['TEMPLATE']
        new_template = get_pool_element(Template, REINSTALL_TEMPLATE_ID, @client)
        new_template.update(
            "NIC = [
                IP=\"#{ip}\",
                MAC=\"#{vm_xml['VM']['TEMPLATE']['NIC']['MAC']}\",
                NETWORK=\"#{vm_xml['VM']['TEMPLATE']['NIC']['NETWORK']}\",
                NETWORK_UNAME=\"#{vm_xml['VM']['TEMPLATE']['NIC']['NETWORK_UNAME']}\",
                SECURITY_GROUPS=\"#{vm_xml['VM']['TEMPLATE']['NIC']['SECURITY_GROUPS']}\" ]
            CPU = \"#{old_template['CPU']}\"
            MEMORY = \"#{old_template['MEMORY']}\"
            VCPU = \"#{old_template['VCPU']}\"
            DESCRIPTION = \"#{old_template['DESCRIPTION']}\"
            PUBLIC_CLOUD = [
                TYPE=\"#{old_template['PUBLIC_CLOUD']['TYPE']}\",
                VM_TEMPLATE=\"#{old_template['PUBLIC_CLOUD']['VM_TEMPLATE']}\" ]
            VCENTER_DATASTORE = \"#{old_template['VCENTER_DATASTORE']}\"
            CONTEXT = [
                NETWORK = \"YES\",
                PASSWORD = \"$PASSWORD\",
                SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\"#{Win?(params['templateid'], @client) ? ", USERNAME = \"$USERNAME\" " : " "}]
            USER_INPUTS = [
                CPU = \"#{old_template['USER_INPUTS']['CPU']}\",
                VCPU = \"#{old_template['USER_INPUTS']['VCPU']}\",
                MEMORY = \"#{old_template['USER_INPUTS']['MEMORY']}\",
                PASSWORD = \"M|password|RootPassword\"#{Win?(params['templateid'], @client) ? ", USERNAME = \"M|text|USERNAME\" " : " "}]
            ",
            true
        )
        
        begin
            vmid = VMCreate(params['userid'], params['login'], REINSTALL_TEMPLATE_ID, params['passwd'], @client, params['release'])
        rescue => e
            LOG e, 'DEBUG'
        end
        $thread_locks[:reinstall].delete_at 0
        
        if params['ansible'] && params['release'] then
            Thread.new do
                until STATE(vmid) == 3 && LCM_STATE(vmid) == 3 do
                    sleep(15)
                end
                sleep(60)
                AnsibleController(params.merge({'super' => "Reinstall ->", 'ip' => GetIP(vmid), 'vmid' => vmid}))
            end
            LOG "Install-thread started, you should wait until the #{params['ansible-service']} will be installed", 'NewAccount -> AnsibleController'
        end
        LOG "VM#{params['vmid']} has been reinstalled", "Reinstall"
        return { 'vmid' => vmid, 'vmid_old' => params['vmid'], 'ip' => GetIP(vmid), 'ip_old' => ip }
    end
    def test(params, request)
        return request
    end
end