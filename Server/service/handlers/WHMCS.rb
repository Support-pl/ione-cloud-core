require 'json'
require 'nori'
require 'net/ssh'

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
        return {'error' => "TemplateLoadError"} if params['templateid'].nil?
        LOG "Creating new user for #{params['login']}", "NewAccount"
        userid = UserCreate(params['login'], params['password'], params['groupid'].to_i, @client) if params['test'].nil?
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
                AnsibleController(params)
            end
            LOG "Install-thread started, you should wait until the #{service} will be installed", 'NewAccount -> AnsibleController'
        end
        #endAnsibleController
        LOG "New User account and vm created", "NewAccount"
        return {'userid' => userid, 'vmid' => vmid, 'ip' => GetIP(vmid)}
    end
    def AnsibleController(params)
        LOG "#{params['ansible-service']} should be installed on VM##{params['vmid']}", "NewAccount -> AnsibleController"
        service, ip, vmid, = params['ansible-service'].chomp, GetIP(params['vmid']), params['vmid']

        begin
            Net::SSH.start(ANSIBLE_HOST, ANSIBLE_HOST_USER, :password => ANSIBLE_HOST_PASSWORD, :port => ANSIBLE_HOST_PORT) do | host |
                ansible_hosts = host.exec!('cat /etc/ansible/hosts').split(/\n/) # Получение списка хостов и групп установки
                ansible_hosts[ansible_hosts.index("[install#{service}clients]") + 1] = "#{ip}:#{USERS_VMS_SSH_PORT} ansible_connection=ssh ansible_ssh_user=root ansible_ssh_pass=#{params['passwd']}"
                #^ Запись в требуемую группу установки(прим. installvestaclients) данных доступа хоста
                host.exec!("echo '#{ansible_hosts.join("\n")}' > /etc/ansible/hosts") # Обновление файла
                playbook = host.exec!("cat /etc/ansible/#{service}/clients/#{service}_pattern.yml") # Получение содержимого шаблонного файла playbook
                whmcs_data = GetWHMCSData(params['login'], params) # Получение пользовательских данных из WHMCS
                YAML.load(playbook)[0]['vars'].keys.each do | var | # Запись пользовательских данных в плейбук
                    playbook.gsub!(ANSIBLE_DEFAULT_DATA[var], whmcs_data[var])
                end if !YAML.load(playbook)[0]['vars'].nil?
                host.exec!("echo '#{playbook}' > /etc/ansible/#{service}/clients/#{service}.yml") # Запись обновленного плейбука в файл
                host.exec!("ansible-playbook /etc/ansible/#{service}/clients/#{service}.yml") # Запуск установки
            end
        rescue => e # Хэндлер ошибки в коде или отсутсвия файлов на сервере Ansible
            LOG "An Error occured, while installing #{service} on #{ip}", "NewAccount -> AnsibleController"
            Thread.exit
        end
        LOG "#{service} installed on #{ip}", "NewAccount -> AnsibleController"
    end
    def Suspend(params, log = true)
        if !params['force'] then
            LOG "Suspend query call params: #{params.inspect}", "Suspend" if !params['force']
            return nil if !params['force']
        end
        LOG "Suspend query for User##{params['userid']} Accepted!", "Suspend" if log
        return "Poshel nahuj so svoimi nulami!!!" if params['userid'].to_i == 0
        Delete(params['userid'])
        LOG "Suspending VM#{params['vmid']}", "Suspend" if log
        VirtualMachine.new(VirtualMachine.build_xml(params['vmid']), @client).suspend
        return nil
    end
    def Unsuspend(params)
        if !params['force'] then            
            LOG "Unsuspend query call params: #{params.inspect}", "Unuspend" if !params['force']
            return nil if !params['force']
        end
        LOG "Unuspending User #{params['login']} and VM ##{params['vmid']}", "Unsuspend"
        userid = UserCreate(params['login'], params['password'], params['groupid'].to_i, @client)
        vm = VirtualMachine.new(VirtualMachine.build_xml(params['vmid']), @client)
        vm.chown(userid, USERS_GROUP)
        vm.resume
        user = User.new(User.build_xml(userid), @client)
        user.info!
        used = Nori.new.parse(user.to_xml)['USER']['VM_QUOTA']['VM']
        user.set_quota("VM=[ CPU=\"#{used['CPU_USED']}\", MEMORY=\"#{used['MEMORY_USED']}\", SYSTEM_DISK_SIZE=\"-1\", VMS=\"#{used['VMS_USED']}\" ]")    
        return { 'userid' => userid }
    end
    def Reboot(vmid)
        LOG "Rebooting VM#{vmid}", "Reboot"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.reboot(true) # true означает, что будет вызвана функция reboot-hard
    end
    def Terminate(userid, vmid, force = false)
        LOG "Terminate query call params: {\"userid\" => #{userid}, \"vmid\" => #{vmid}}", "Terminate"
        return nil if !force
        if userid == nil || vmid == nil then
            LOG "Terminate query rejected! 1 of 2 params is nilClass!", "Terminate"
            return 1
        elsif userid == 0 then
            LOG "Terminate query rejected! Tryed to delete root-user(oneadmin)", "Terminate"
        end
        Delete(userid)
        LOG "Terminating VM#{vmid}", "Terminate"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.recover(3)
    end
    def Shutdown(vmid)
        LOG "Shutting down VM#{vmid}", "Shutdown"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.poweroff
    end
    def Release(vmid)
        LOG "New Release Order Accepted!", "Release"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.release # <- Release
    end
    def Delete(userid)
        if userid == 0 then
            LOG "Delete query rejected! Tryed to delete root-user(oneadmin)", "Delete"
        end
        LOG "Deleting User ##{userid}", "Delete"
        user = User.new(User.build_xml(userid), @client)
        user.delete
    end
    def VM_XML(vmid)
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.info
        return vm.to_xml
    end
    def activity_log()
        LOG "Log file content has been copied remotely", "activity_log"
        log = File.read("#{ROOT}/log/activities.log")
        return log
    end
    def Resume(vmid)
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.resume
    end
    def GetIP(vmid)
        doc_hash = Nori.new.parse(VM_XML(vmid))
        return doc_hash['VM']['TEMPLATE']['CONTEXT']['ETH0_IP']
    end

    def RMSnapshot(vmid, snapid, log = false)
        LOG "Deleting snapshot(ID: #{snapid}) for VM#{vmid}", "RMSnapshot" if log
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.snapshot_delete(snapid)
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
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.info!        
        return vm.state
    end
    def STATE_STR(vmid)
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.info!
        return vm.state_str
    end
    def LCM_STATE(vmid)
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.info!
        return vm.lcm_state
    end
    def LCM_STATE_STR(vmid)
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.info!
        return vm.lcm_state_str
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
        user = User.new(User.build_xml(userid), @client)
        user.info!
        return user.to_xml
    end
    def Reinstall(params)
        LOG "Reinstalling VM#{params['vmid']}", 'Reinstall'
        vmid = params['vmid']
        ip, vm = GetIP(vmid), VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm_xml = Nori.new.parse(vm.info! || vm.to_xml)
        vm.terminate(true)
        vn = VirtualNetwork.new(VirtualNetwork.build_xml(vm_xml['VM']['TEMPLATE']['NIC']['NETWORK_ID'].to_i), @client)
        vn.hold(ip)
        vmid = VMCreate(params['userid'], params['login'], params['templateid'].to_i, params['passwd'], @client, params['release'])
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        
        Thread.new do
            until STATE(vmid) == 3 && LCM_STATE(vmid) == 3 do
                LOG "Waiting for VM#{vmid} be deployed", 'META'
                sleep(60)
            end
            sleep(30)
            vn.release(ip)
            vm.nic_attach(
            "NIC = [ AR_ID=\"#{vm_xml['VM']['TEMPLATE']['NIC']['AR_ID']}\",
                    BRIDGE=\"#{vm_xml['VM']['TEMPLATE']['NIC']['BRIDGE']}\",
                    CLUSTER_ID=\"#{vm_xml['VM']['TEMPLATE']['NIC']['CLUSTER_ID']}\",
                    IP=\"#{vm_xml['VM']['TEMPLATE']['NIC']['IP']}\",
                    MAC=\"#{vm_xml['VM']['TEMPLATE']['NIC']['MAC']}\",
                    NETWORK=\"#{vm_xml['VM']['TEMPLATE']['NIC']['NETWORK']}\",
                    NETWORK_ID=\"#{vm_xml['VM']['TEMPLATE']['NIC']['NETWORK_ID']}\",
                    NETWORK_UNAME=\"#{vm_xml['VM']['TEMPLATE']['NIC']['NETWORK_UNAME']}\",
                    SECURITY_GROUPS=\"#{vm_xml['VM']['TEMPLATE']['NIC']['SECURITY_GROUPS']}\",
                    TARGET=\"#{vm_xml['VM']['TEMPLATE']['NIC']['TARGET']}\",
                    VN_MAD=\"#{vm_xml['VM']['TEMPLATE']['NIC']['VN_MAD']}\"
                ]"
            )
            LOG "VM#{vmid} has been reinstalled", "Reinstall"
            vm.nic_detach 0
        end
        return { 'vmid' => vmid, 'ip' => ip }
    end
    def test(vmid)
        LOG LCM_STATE(vmid)
        LOG STATE(vmid)
    end
end