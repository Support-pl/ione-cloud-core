require 'json'
require 'nori'
require 'net/ssh'

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
                AnsibleController(params.merge({'super' => "NewAccount ->", 'ip' => GetIP(vmid)}))
            end
            LOG "Install-thread started, you should wait until the #{service} will be installed", 'NewAccount -> AnsibleController'
        end
        #endAnsibleController
        LOG "New User account and vm created", "NewAccount"
        return {'userid' => userid, 'vmid' => vmid, 'ip' => GetIP(vmid)}
    end
=begin
    Обязательные параметры для AnsibleController:{
        'ansible-service' => % Имя сервиса, например, vesta %,
        'vmid' => % VM ID машины %,
        'ip' => % IP машины %,
        'super' => % Имя метода вызывающего данный, если таковой имеется %
        >.. => % Специфические параметры для получения данных и сторонних источников, пример: %
        'serviceid' => % ID сервиса в биллинге %
        'passwd' => % Пароль для ВМ % 
    }
=end
    def AnsibleController(params)
        LOG "Query rejected: Ansible is not configured", "#{params['super']}AnsibleController"
        LOG "#{params['ansible-service']} should be installed on VM##{params['vmid']}", "#{params['super']}AnsibleController"
        service, ip, vmid, = params['ansible-service'].chomp, params['ip'], params['vmid']
        
        obj, id = MethodThread.new(:method => __method__).with_id # Получение объекта MethodThread и его ID
        $thread_locks[:ansiblecontroller] << obj.thread_obj( # Запись в объект объекта потока
            Thread.new do
                begin
                    # Запуск SSH сессии с сервером на котором находится Ansible
                    Net::SSH.start(ANSIBLE_HOST, ANSIBLE_HOST_USER, :password => ANSIBLE_HOST_PASSWORD, :port => ANSIBLE_HOST_PORT) do | host |
                        # Получение списка хостов для установки
                        ansible_hosts = host.exec!('cat /etc/ansible/hosts').split(/\n/)
                        # Запись в требуемую группу установки(прим. installvestaclients) данных доступа хоста
                        ansible_hosts[ansible_hosts.index("[install#{service}clients]") + 1] = "#{ip}:#{USERS_VMS_SSH_PORT} ansible_connection=ssh ansible_ssh_user=root ansible_ssh_pass=#{params['passwd']}"
                        # Запись хостов обратно в файл hosts
                        host.exec!("echo '#{ansible_hosts.join("\n")}' > /etc/ansible/hosts")
                        # Получение содержимого шаблонного файла playbook
                        playbook = host.exec!("cat /etc/ansible/#{service}/clients/#{service}_pattern.yml")
                        # Создание объекта класса AnsibleDataGetter для получения данных из сторонних источников
                        getter = AnsibleDataGetter.new
                        # В случае наличия переменных, получение значений для них с помощью одноименных функций в AnsibleDataGetter
                        playbook[0]['vars'].each_key { | key | puts playbook[0]['vars'][key] = getter.send(key, params) } if !YAML.load(playbook)[0]['vars'].nil?
                        # Конвертация хэша в YAML строку
                        playbook = YAML.dump playbook
                        # Запись плейбука в основной файл плейбука
                        host.exec!("echo '#{playbook}' > /etc/ansible/#{service}/clients/#{service}.yml")
                        # Запуск плейбука
                        host.exec!("ansible-playbook /etc/ansible/#{service}/clients/#{service}.yml")
                        # Вот тут будет проверка итогов работы ansible
                    end
                rescue => e # Хэндлер ошибки в коде или отсутсвия файлов на сервере Ansible
                    LOG "An Error occured, while installing #{service} on #{ip}", "NewAccount -> AnsibleController"
                    Thread.exit
                    $thread_locks[:ansiblecontroller].delete_at 0 # Удаление себя из очереди на выполнение
                end
                LOG "#{service} installed on #{ip}", "NewAccount -> AnsibleController"
                $thread_locks[:ansiblecontroller].delete_at 0
            end
        )
    end
    def Suspend(params, log = true)
        if !params['force'] then
            LOG "Suspend query call params: #{params.inspect}", "Suspend" if !params['force']
            return nil if !params['force']
        end
        LOG "Params: #{params.inspect} | log = #{log}", "Suspend" if DEBUG
        LOG "Suspend query for User##{params['userid']} Accepted!", "Suspend" if log
        # Обработка ошибки нулевого пользователя, удалять root как-то некрасиво
        return "Poshel nahuj so svoimi nulami!!!" if params['userid'].to_i == 0
        # Удаление пользователя
        Delete(params['userid'])
        LOG "Suspending VM#{params['vmid']}", "Suspend" if log
        # Приостановление виртуальной машины
        get_pool_element(VirtualMachine, params['vmid'], @client).suspend
        # VirtualMachine.new(VirtualMachine.build_xml(params['vmid']), @client).suspend
        return nil
    end
    def Unsuspend(params)
        if !params['force'] then            
            LOG "Unsuspend query call params: #{params.inspect}", "Unuspend" if !params['force']
            return nil if !params['force']
        end
        LOG "Params: #{params.inspect} | log = #{log}", "Unsuspend" if DEBUG
        LOG "Unuspending User #{params['login']} and VM ##{params['vmid']}", "Unsuspend"
        # Создание копии удаленного(приостановленного) аккаунта
        userid = UserCreate(params['login'], params['password'], params['groupid'].to_i, @client)
        vm = get_pool_element(VirtualMachine, params['vmid'], @client)
        # vm = VirtualMachine.new(VirtualMachine.build_xml(params['vmid']), @client)
        # Отдаем машину новой учетке
        vm.chown(userid, USERS_GROUP)
        # Запускаем машину
        vm.resume
        user = get_pool_element(User, userid, @client)
        # user = User.new(User.build_xml(userid), @client)
        # Получение информации о квотах пользователя
        used = (user.info! || user.to_hash)['USER']['VM_QUOTA']['VM']
        # Установление квот на уровень количества ресурсов выданных пользователю
        user.set_quota("VM=[ CPU=\"#{used['CPU_USED']}\", MEMORY=\"#{used['MEMORY_USED']}\", SYSTEM_DISK_SIZE=\"-1\", VMS=\"#{used['VMS_USED']}\" ]")    
        return { 'userid' => userid }
    end
    def Reboot(vmid)
        LOG "Rebooting VM#{vmid}", "Reboot"
        LOG "Params: vmid = #{vmid}", "Reboot" if DEBUG
        get_pool_element(VirtualMachine, vmid, @client).reboot(true) # true означает, что будет вызвана функция reboot-hard
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client).reboot(true)
    end
    def Terminate(userid, vmid, force = false)
        LOG "Terminate query call params: {\"userid\" => #{userid}, \"vmid\" => #{vmid}}", "Terminate"
        return nil if !force
        # Пробуем НЕ удалить корень
        if userid == nil || vmid == nil then
            LOG "Terminate query rejected! 1 of 2 params is nilClass!", "Terminate"
            return 1
        elsif userid == 0 then
            LOG "Terminate query rejected! Tryed to delete root-user(oneadmin)", "Terminate"
        end
        # Удаляем пользователя
        Delete(userid)
        LOG "Terminating VM#{vmid}", "Terminate"
        get_pool_element(VirtualMachine, vmid, @client).recover 3 # recover с параметром 3 означает полное удаление с диска
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client).recover(3)
    end
    def Shutdown(vmid) # Выключение машины
        LOG "Shutting down VM#{vmid}", "Shutdown"
        get_pool_element(VirtualMachine, vmid, @client).poweroff
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client).poweroff
    end
    def Release(vmid)
        LOG "New Release Order Accepted!", "Release"
        get_pool_element(VirtualMachine, vmid, @client).release
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client).release # <- Release
    end
    def Delete(userid) # Удаление пользователя
        if userid == 0 then
            LOG "Delete query rejected! Tryed to delete root-user(oneadmin)", "Delete"
        end
        LOG "Deleting User ##{userid}", "Delete"
        get_pool_element(User, userid, @client).delete
        # user = User.new(User.build_xml(userid), @client).delete
    end
    def VM_XML(vmid)
        vm = get_pool_element(VirtualMachine, vmid, @client)
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.info! || vm.to_xml
    end
    def activity_log()
        LOG "Log file content has been copied remotely", "activity_log"
        log = File.read("#{ROOT}/log/activities.log")
        return log
    end
    def Resume(vmid)
        get_pool_element(VirtualMachine, vmid, @client).resume
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client).resume
    end
    def GetIP(vmid)
        doc_hash = Nori.new.parse(VM_XML(vmid))
        return doc_hash['VM']['TEMPLATE']['CONTEXT']['ETH0_IP']
    end

    def RMSnapshot(vmid, snapid, log = false)
        LOG "Deleting snapshot(ID: #{snapid}) for VM#{vmid}", "RMSnapshot" if log
        get_pool_element(VirtualMachine. vmid, @client).snapshot_delete(snapid)
        # VirtualMachine.new(VirtualMachine.build_xml(vmid), @client).snapshot_delete(snapid)
    end
    def log(msg)
        LOG(msg, "log")
	    return "YEP!"
    end
    def stop(passwd)
        LOG "Trying to stop server manually", "stop"
        if(passwd.crypt == "keLa9zoht45RY") then
            LOG "Server Stopped Manualy", "stop"
            Kernel.abort("[ #{time()} ] Server Stopped Remotely")
        end
        return nil
    end
    def STATE(vmid)
        vm = get_pool_element(VirtualMachine, vmid, @client)
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.info! || vm.state
    end
    def STATE_STR(vmid)
        vm = get_pool_element(VirtualMachine, vmid, @client)
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.info! || vm.state_str
    end
    def LCM_STATE(vmid)
        vm = get_pool_element(VirtualMachine, vmid, @client)
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.info! || vm.lcm_state
    end
    def LCM_STATE_STR(vmid)
        vm = get_pool_element(VirtualMachine, vmid, @client)
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.info! || vm.lcm_state_str
    end
    def compare_info()
        def get_name(uid)
            return `mysql opennebula -BNe "select name from user_pool where oid = #{uid}"`.chomp
        end
        
        all_active_vms = `mysql opennebula -BNe "select oid from vm_pool where state = 3 or state = 8"`.split(/\n/)
        all_active_vms_owners = `mysql opennebula -BNe "select uid from vm_pool where state = 3 or state = 8"`.split(/\n/)
        

        info = Array.new
        
        for i in 0..all_active_vms.length do
            break if all_active_vms[i].nil?
            info << {
                :vmid => all_active_vms[i], :userid => all_active_vms_owners[i], 
                :login => get_name(all_active_vms_owners[i])
            }
        end
        
        return info.to_json
    end
    def GetUserInfo(userid)
        user = get_pool_element(User, userid, @client)
        # user = User.new(User.build_xml(userid), @client)
        return user.info! || user.to_xml
    end
    def Reinstall(params)
        LOG params.inspect, 'META'
        LOG "Reinstalling VM#{params['vmid']}", 'Reinstall'
        params.each do | item |
            return "ReinstallError - some params are nil", params if item.nil?
        end

        obj, id = MethodThread.new(:method => __method__).with_id
        $thread_locks[:reinstall] << obj.thread_obj(Thread.current)
        until $thread_locks[:reinstall][0].id == id || $thread_locks[:reinstall].empty? do
            sleep(5)
        end
        $thread_locks[:reinstall][0].start

        vmid = params['vmid']
        ip, vm = GetIP(vmid), get_pool_element(VirtualMachine, vmid, @client)
        vm_xml = Nori.new.parse(vm.info! || vm.to_xml)
        vm.terminate(true)
        while STATE_STR(vmid) != 'DONE' do
            sleep(1)
        end

        old_template = get_pool_element(Template, params['templateid'].to_i, @client)
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
            LOG e, 'META'
            LOG e.message, 'META'
        end

        if params['ansible'] && params['release'] then
            Thread.new do
                until STATE(vmid) == 3 && LCM_STATE(vmid) == 3 do
                    sleep(15)
                end
                sleep(60)
                AnsibleController(params.merge({'super' => "Reinstall ->", 'ip' => GetIP(vmid)}))
            end
            LOG "Install-thread started, you should wait until the #{service} will be installed", 'NewAccount -> AnsibleController'
        end
        $thread_locks[:reinstall].delete_at 0
        LOG "VM#{vmid} has been reinstalled", "Reinstall"
        return { 'vmid' => vmid, 'vmid_old' => params['vmid'], 'ip' => GetIP(vmid), 'ip_old' => ip }
    end
    def test(delay)
        obj, id = MethodThread.new(:timeout => 30, :method => __method__).with_id
        $thread_locks[:test] << obj.thread_obj(
            Thread.new do
                until $thread_locks[:test][0].id == id || $thread_locks[:test].empty? do
                    sleep(5)
                end
                $thread_locks[:test][0].start
                LOG "START#{id.to_s}", 'META'
                sleep(delay)
                LOG "END__#{id.to_s}", 'META'
                $thread_locks[:test].delete_at 0
            end
        )
        return $thread_locks[:test]
    end        
    def locks_stat(key = nil)
        return $thread_locks
    end
end