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
class IONe
    def NewAccount(params, trace = ["NewAccount method called:#{__LINE__}"])
        begin
            installid, err = Time.now.to_i.to_s(16).crypt(params['login']), ""
            $proc << "NewAccount_#{installid}"

            LOG params.merge!({ :method => 'NewAccount' }).debug_out, 'DEBUG'

            return $proc.delete "NewAccount_#{installid}" if params['debug'] == 'turn_method_off'
            return {'userid' => 666, 'vmid' => 666, 'ip' => '0.0.0.0'} || kill_proc("NewAccount_#{installid}") if params['debug'] == 'data'   

            LOG "New Account for #{params['login']} Order Accepted! #{params['trial'] == true ? "VM is Trial" : nil}", "NewAccount" # Логи
            LOG "Params: #{params.inspect}", 'NewAccount' if DEBUG # Логи
            LOG "Error: TemplateLoadError", 'NewAccount' if params['templateid'].nil? # Логи
            return {'error' => "TemplateLoadError"}, (trace << "TemplateLoadError:#{__LINE__ - 1}") || kill_proc("NewAccount_#{installid}") if params['templateid'].nil?
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
                    AnsibleController(params.merge({
                        'super' => "NewAccount ->", 'host' => "#{GetIP(vmid)}:#{CONF['OpenNebula']['users-vms-ssh-port']}", 'vmid' => vmid
                    }))
                end
                LOG "Install-thread started, you should wait until the services will be installed", 'NewAccount -> AnsibleController'
            end
            #endAnsibleController
            LOG "New User account and vm created", "NewAccount"
            return {'userid' => userid, 'vmid' => vmid, 'ip' => GetIP(vmid)} || kill_proc("NewAccount_#{installid}")
        rescue => e
            return { 'error' => e.message, 'trace' => trace} || kill_proc("NewAccount_#{installid}")
        end
    end
    def Reinstall(params, trace = ["Reinstall method called:#{__LINE__}"])
        begin
            installid = Time.now.to_i.to_s(16).crypt(params['login'])
            $proc << "Reinstall_#{installid}"

            # Сделать проверку на корректность присланных данных: существует ли юзер, существует ли ВМ
            LOG params.merge!({ :method => 'Reinstall' }).debug_out, 'DEBUG'
            return kill_proc "Reinstall_#{installid}" if params['debug'] == 'turn_method_off'
            return { 'vmid' => 666, 'vmid_old' => params['vmid'], 'ip' => '6.6.6.6', 'ip_old' => '0.0.0.0' } || kill_proc("Reinstall_#{installid}") if params['debug'] == 'data'   

            LOG "Reinstalling VM#{params['vmid']}", 'Reinstall'

            params['vmid'], params['groupid'], params['userid'], params['templateid'] = params['vmid'].to_i, params['groupid'].to_i, params['userid'].to_i, params['templateid'].to_i

            if params['vmid'] * params['groupid'] * params['userid'] * params['templateid'] == 0 then
                LOG "ReinstallError - some params are nil", 'Reinstall'
                return "ReinstallError - some params are nil" || kill_proc("Reinstall_#{installid}")
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
            LOG 'Creating new VM', 'DEBUG'
            vmid = template.instantiate(params['login'] + '_vm', false, nic)
            
            Thread.new do
                LOG 'Waiting until terminate process will over', 'Reinstall'
                until STATE_STR(params['vmid']) == 'DONE' do
                    sleep(0.2)
                end if params['release']
                LOG 'Deploying VM to the host', 'DEBUG'
                onblock(VirtualMachine, vmid) do | vm |
                    vm.deploy(CONF['OpenNebula']['default-node-id']) if params['release']
                    vm.chown(params['userid'], USERS_GROUP)
                end

                if params['ansible'] && params['release'] then
                    Thread.new do
                        until STATE(vmid) == 3 && LCM_STATE(vmid) == 3 do
                            sleep(15)
                        end
                        sleep(60)
                        AnsibleController(params.merge({'super' => "Reinstall ->", 'host' => "#{ip}:#{CONF['OpenNebula']['users-vms-ssh-port']}", 'vmid' => vmid}))
                    end
                    LOG "Install-thread started, you should wait until the #{params['ansible-service']} will be installed", 'Reinstall -> AnsibleController'
                end
                LOG "VM#{params['vmid']} has been recreated and deploying now", "Reinstall"
            end

            return { 'vmid' => vmid, 'vmid_old' => params['vmid'], 'ip' => GetIP(vmid), 'ip_old' => ip } || kill_proc("Reinstall_#{installid}")
        rescue => e
            return e.message, trace || kill_proc("Reinstall_#{installid}")
        end
    end
    def CreateVMwithSpecs(params, trace = ["#{__method__.to_s} method called:#{__LINE__}"])
        LOG params.merge!(:method => __method__.to_s).debug_out, 'DEBUG'
        # return
        begin
            params['cpu'], params['ram'], params['drive'], params['iops'] = params['cpu'].to_i, params['ram'].to_i, params['drive'].to_i, params['iops'].to_i

            ###################### Doing some important system stuff ###############################################################
            
            installid, err = Time.now.to_i.to_s(16).crypt(params['login']), ""
            $proc << "CreateVMwithSpecs_#{installid}"
            return nil if DEBUG
            # return {'userid' => 666, 'vmid' => 666, 'ip' => '0.0.0.0'}        
            LOG_TEST "CreateVMwithSpecs for #{params['login']} Order Accepted! #{params['trial'] == true ? "VM is Trial" : nil}" # Логи
            LOG_TEST "Params: #{params.inspect}" if DEBUG # Логи
            LOG_TEST "Error: TemplateLoadError" if params['templateid'].nil? # Логи
            return {'error' => "TemplateLoadError"}, (trace << "TemplateLoadError:#{__LINE__ - 1}") if params['templateid'].nil?
            LOG_TEST "Creating new user for #{params['login']}"

            #####################################################################################################################

            #####   Initializing useful variables   #####
                        userid, vmid = 0, 0
            ##### Initializing useful variables END #####

            #####   Creating new User   #####
            trace << "Creating new user:#{__LINE__ + 1}"
            userid, user = UserCreate(params['login'], params['password'], params['groupid'].to_i, @client, true) if params['test'].nil?
            LOG_TEST "Error: UserAllocateError" if userid == 0
            trace << "UserAllocateError:#{__LINE__ - 2}" if userid == 0
            return {'error' => "UserAllocateError"} if userid == 0
            ##### Creating new User END #####
            
            #####   Creating and Configuring VM   #####
            LOG_TEST "Creating VM for #{params['login']}"
            trace << "Creating new VM:#{__LINE__ + 1}"
            onblock('temp', params['templateid']) do | t |
                t.info!
                specs = "VCPU = #{params['cpu']}
                MEMORY = #{params['ram'] * (params['units'] == 'GB' ? 1024 : 1)}
                DISK = [
                    IMAGE_ID = \"#{t.to_hash['VMTEMPLATE']['TEMPLATE']['DISK']['IMAGE_ID']}\",
                    SIZE = \"#{params['drive'] * (params['units'] == 'GB' ? 1024 : 1)}\"]"
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
            LOG_TEST "New User account created"
            
            LOG_TEST 'Configuring VM Template'
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
            ##### Creating and Configuring VM END #####            

            #####   PostDeploy Activity define   #####
            Thread.new do
                #LimitsController
            
                until STATE(vmid) == 3 && LCM_STATE(vmid) == 3 do
                    sleep(30)
                end

                onblock('vm', vmid) do | vm |
                    LOG "Executing Limits Configurator for VM#{vmid}", 'DEBUG'
                    vm.setResourcesAllocationLimits(cpu: params['cpu'] * CONF['vCenter']['cpu-limits-koef'], ram: params['ram'] * (params['units'] == 'GB' ? 1024 : 1), iops: params['iops'])
                end

                #endLimitsController
                #TrialController
                if params['trial'] then
                    LOG "VM #{vmid} will be suspended in 4 hours", 'CreateVMwithSpecs -> TrialController'
                    trace << "Creating trial counter thread:#{__LINE__ + 1}"
                    Thread.new do # Отделение потока с ожидаением и приостановлением машины+пользователя от основного
                        sleep(TRIAL_SUSPEND_DELAY)
                        Suspend({'userid' => userid, 'vmid' => vmid}, false)
                        LOG "TrialVM ##{vmid} suspended", 'CreateVMwithSpecs -> TrialController'
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
                        AnsibleController(params.merge({
                            'super' => "CreateVMwithSpecs ->", 'host' => "#{GetIP(vmid)}:#{CONF['OpenNebula']['users-vms-ssh-port']}", 'vmid' => vmid
                        }))
                    end
                    LOG "Install-thread started, you should wait until the #{params['ansible-service']} will be installed", 'CreateVMwithSpecs -> AnsibleController'
                end
                #endAnsibleController
            end if params['release']
            ##### PostDeploy Activity define END #####

            LOG_TEST 'Post-Deploy joblist defined, basic installation job ended'
            return {'userid' => userid, 'vmid' => vmid, 'ip' => GetIP(vmid)}
        rescue => e
            out = { :exeption => e.message, :trace => trace << 'END_TRACE' }
            LOG out.debug_out, 'DEBUG'
            return out
        end
    end
end