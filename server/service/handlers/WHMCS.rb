# Очередь выполнения для методов
# На каждый метод, создается ключ(прим. thread_locks[:NewAccount]) под которым есть массив объектов класса MethodThread
# Этот массив реализует очередь выполнения
$thread_locks = Hash.new { |hash, key| hash[key] = Array.new }

$proc = []
def kill_proc(id)
    begin
        $proc.delete id
    rescue
    end
    return nil
end
def proc_id_gen(method)
    id = "#{method.to_s}_" + Time.now.to_i.to_s(16).crypt(method.to_s)
    $proc << id
    return id
end    
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
        LOG "Test message received, text: #{msg}", "Test" if msg != 'PING'
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
    def NewAccount(params, trace = ["NewAccount method called:#{__LINE__}"])
        begin
            installid, err = Time.now.to_i.to_s(16).crypt(params['login']), ""
            $proc << "NewAccount_#{installid}"
            at_exit do
                $proc.delete "NewAccount_#{installid}"
            end
            LOG params.out, "DEBUG"
            return nil if DEBUG
            # return {'userid' => 666, 'vmid' => 666, 'ip' => '0.0.0.0'}        
            LOG "New Account for #{params['login']} Order Accepted! #{params['trial'] == true ? "VM is Trial" : nil}", "NewAccount" # Логи
            LOG "Params: #{params.inspect}", 'NewAccount' if DEBUG # Логи
            LOG "Error: TemplateLoadError", 'NewAccount' if params['templateid'].nil? # Логи
            return {'error' => "TemplateLoadError"}, (trace << "TemplateLoadError:#{__LINE__ - 1}") if params['templateid'].nil?
            LOG "Creating new user for #{params['login']}", "NewAccount"

            #####################################################################################################################

            trace << "Creating new user:#{__LINE__ + 1}"
            userid = UserCreate(params['login'], params['password'], params['groupid'].to_i, @client) if params['test'].nil?
            LOG "Error: UserAllocateError" if userid == 0
            trace << "UserAllocateError:#{__LINE__ + 1}"
            return {'error' => "UserAllocateError"} if userid == 0
            LOG "Creating VM for #{params['login']}", "NewAccount"
            trace << "Creating new VM:#{__LINE__ + 1}"
            vmid = VMCreate(userid, params['login'], params['templateid'].to_i, params['passwd'], @client, params['release']) if params['test'].nil?
            #TrialController
            if params['trial'] then
                LOG "VM #{vmid} will be suspended in 4 hours", 'NewAccount -> TrialController'
                trace << "Creating trial counter thread:#{__LINE__ + 1}"
                Thread.new do # Отделение потока с ожидаением и приостановлением машины+пользователя от основного
                    sleep(TRIAL_SUSPEND_DELAY)
                    Suspend({'userid' => userid, 'vmid' => vmid}, false)
                    LOG "TrialVM ##{vmid} suspended", 'NewAccount -> TrialController'
                end
            end
            #endTrialController
            #AnsibleController
            if params['ansible'] && params['release'] then
                trace << "Creating Ansible Installer thread:#{__LINE__ + 1}"            
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
        rescue => e
            return { 'error' => e.message, 'trace' => trace}
        end
    end
    def Reinstall(params, trace = ["Reinstall method called:#{__LINE__}"])
        begin
            installid = Time.now.to_i.to_s(16).crypt(params['login'])
            $proc << "Reinstall_#{installid}"
            at_exit do
                $proc.delete "Reinstall_#{installid}"
            end
            # Сделать проверку на корректность присланных данных: существует ли юзер, существует ли ВМ
            LOG params.out, 'DEBUG' if DEBUG
            # return if DEBUG
            LOG "Reinstalling VM#{params['vmid']}", 'Reinstall'

            params['vmid'], params['groupid'], params['userid'], params['templateid'] = params['vmid'].to_i, params['groupid'].to_i, params['userid'].to_i, params['templateid'].to_i

            if params['vmid'] * params['groupid'] * params['userid'] * params['templateid'] == 0 then
                LOG "ReinstallError - some params are nil", 'Reinstall'
                return "ReinstallError - some params are nil"
            end

            LOG 'Initializing vm object', 'DEBUG'
            vm = onblock(VirtualMachine, params['vmid'])
            LOG 'Collecting data from old template', 'DEBUG'
            nic, context = vm.info! || vm.to_hash['VM']['TEMPLATE']['NIC'], vm.to_hash['VM']['TEMPLATE']['CONTEXT']
            
            LOG 'Generating new template', 'DEBUG'
            ip, nic = nic['IP'], "NIC = [\n\tIP=\"#{nic['IP']}\",\n\tMAC=\"#{nic['MAC']}\",\n\tNETWORK=\"#{nic['NETWORK']}\",\n\tNETWORK_UNAME=\"#{nic['NETWORK_UNAME']}\"\n]\nCONTEXT = [\n\tPASSWORD=\"#{context['PASSWORD']}\"\n]"
            LOG 'Initializing template obj'
            template = onblock(Template, params['templateid'])
            
            vm.terminate(true)
            while STATE_STR(params['vmid']) != 'DONE' do
                sleep(1)
            end
            LOG 'Creating new VM', 'DEBUG'
            vmid = template.instantiate(params['login'] + '_vm', !params['release'], nic)
            LOG 'Deploying VM to the host', 'DEBUG'
            vm = onblock(VirtualMachine, vmid).deploy(CONF['OpenNebula']['default-node-id'])
            if params['ansible'] && params['release'] then
                Thread.new do
                    until STATE(vmid) == 3 && LCM_STATE(vmid) == 3 do
                        sleep(15)
                    end
                    sleep(60)
                    AnsibleController(params.merge({'super' => "Reinstall ->", 'host' => "#{ip}:#{CONF['OpenNebula']['users-vms-ssh-port']}", 'vmid' => vmid}))
                end
                LOG "Install-thread started, you should wait until the #{params['ansible-service']} will be installed", 'NewAccount -> AnsibleController'
            end
            LOG "VM#{params['vmid']} has been reinstalled", "Reinstall"
            return { 'vmid' => vmid, 'vmid_old' => params['vmid'], 'ip' => GetIP(vmid), 'ip_old' => ip }
        rescue => e
            return e.message, trace
        end
    end
    def CreateVMwithSpecs(params, trace = ["#{__method__.to_s} method called:#{__LINE__}"])
        begin
            params['cpu'], params['ram'], params['drive'] = params['cpu'].to_i, params['ram'].to_i, params['drive'].to_i

            ###################### Doing some important system stuff ###############################################################
            
            installid, err = Time.now.to_i.to_s(16).crypt(params['login']), ""
            $proc << "NewAccount_#{installid}"
            at_exit do
                $proc.delete "NewAccount_#{installid}"
            end
            LOG params.out, "DEBUG"
            return nil if DEBUG
            # return {'userid' => 666, 'vmid' => 666, 'ip' => '0.0.0.0'}        
            LOG "New Account for #{params['login']} Order Accepted! #{params['trial'] == true ? "VM is Trial" : nil}", "NewAccount" # Логи
            LOG "Params: #{params.inspect}", 'NewAccount' if DEBUG # Логи
            LOG "Error: TemplateLoadError", 'NewAccount' if params['templateid'].nil? # Логи
            return {'error' => "TemplateLoadError"}, (trace << "TemplateLoadError:#{__LINE__ - 1}") if params['templateid'].nil?
            LOG "Creating new user for #{params['login']}", "NewAccount"

            #####################################################################################################################

            #####   Initializing useful variables   #####
                        userid, vmid = 0
            ##### Initializing useful variables END #####

            #####   Creating new User   #####
            trace << "Creating new user:#{__LINE__ + 1}"
            userid, user = UserCreate(params['login'], params['password'], params['groupid'].to_i, @client, true) if params['test'].nil?
            LOG "Error: UserAllocateError" if userid == 0
            trace << "UserAllocateError:#{__LINE__ - 2}" if userid == 0
            return {'error' => "UserAllocateError"} if userid == 0
            ##### Creating new User END #####
            
            #####   Creating and Configuring VM   #####
            LOG "Creating VM for #{params['login']}", "NewAccount"
            trace << "Creating new VM:#{__LINE__ + 1}"
            onblock('temp', params['templateid']) do | t |
                t.info!
                specs = "VCPU = #{params['cpu']}
                MEMORY = #{params['ram'] * (params['units'] == 'GB' ? 1024 : 1)}
                DISK = [
                    IMAGE_ID = \"#{t.to_hash['VMTEMPLATE']['TEMPLATE']['DISK']['IMAGE_ID']}\",
                    SIZE = \"#{params['drive'] * (params['units'] == 'GB' ? 1024 : 1)}\",
                    OPENNEBULA_MANAGED = \"NO\" ]"
                vmid = t.instantiate("#{params['login']}_vm", true, specs)
                
            end
            
            def ChooseDS(ds_type)
                dss = DatastoresMonitoring('sys').sort! { | ds | 100 * ds['used'].to_f / ds['full_size'].to_f }
                dss.delete_if { |ds| ds['type'] != ds_type || ds['deploy'] != 'TRUE' }
                ds = dss[rand(dss.size)]
                LOG "Deploying to #{ds['name']}", 'DEBUG'
                return ds['id']
            end
            
            trace << "Updating user quota:#{__LINE__ + 1}"
            user.update_quota_by_vm(
                'append' => true, 'cpu' => params['cpu'],
                'ram' => params['ram'] * (params['units'] == 'GB' ? 1024 : 1),
                'drive' => params['drive'] * (params['units'] == 'GB' ? 1024 : 1)
            )
            
            LOG 'Configuring VM Template', 'NewAccount'
            trace << "Configuring VM Template:#{__LINE__ + 1}"            
            onblock('vm', vmid) do |vm|
                vm.chown(userid, USERS_GROUP)
                
                if Win? params['templateid'], @client then
                    vm.updateconf(
                        "CONTEXT = [ NETWORK=\"YES\", PASSWORD = \"#{params['passwd']}\", SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\", USERNAME = \"Administrator\" ]"
                    )
                else
                    vm.updateconf(
                        "CONTEXT = [ NETWORK=\"YES\", PASSWORD = \"#{params['passwd']}\", SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\" ]"
                    ) # Настройка контекста: изменение root-пароля на заданный
                end
                vm.updateconf(
                    "GRAPHICS = [ LISTEN=\"0.0.0.0\", PORT=\"#{CONF['OpenNebula']['base-vnc-port'] + vmid}\", TYPE=\"VNC\" ]"
                ) # Настройка порта для VNC

                trace << "Deploying VM:#{__LINE__ + 1}"            
                vm.deploy(DEFAULT_HOST, false, ChooseDS(params['ds_type'])) if params['release']
                # vm.deploy(DEFAULT_HOST, false, params['datastore'].nil? ? ChooseDS(params['ds_type']): params['datastore']) if params['release']
            end

            #TrialController
            if params['trial'] then
                LOG "VM #{vmid} will be suspended in 4 hours", 'NewAccount -> TrialController'
                trace << "Creating trial counter thread:#{__LINE__ + 1}"
                Thread.new do # Отделение потока с ожидаением и приостановлением машины+пользователя от основного
                    sleep(TRIAL_SUSPEND_DELAY)
                    Suspend({'userid' => userid, 'vmid' => vmid}, false)
                    LOG "TrialVM ##{vmid} suspended", 'NewAccount -> TrialController'
                end
            end
            #endTrialController
            #AnsibleController
            if params['ansible'] && params['release'] then
                trace << "Creating Ansible Installer thread:#{__LINE__ + 1}"            
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

            ##### Creating and Configuring VM END #####            
        rescue => e
            LOG trace, 'DEBUG'
            return e.message, trace << 'END_TRACE'
        end
    end
    def test(params, request)
        return request
    end
end