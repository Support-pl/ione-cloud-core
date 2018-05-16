class IONe
    # Creates new user account
    # @param [String]   login       - login for new OpenNebula User
    # @param [String]   pass        - password for new OpenNebula User
    # @param [Integer]  groupid     - Secondary group for new user
    # @param [OpenNebula::Client] client
    # @param [Boolean]  object      - Returns userid of the new User and object of new User
    # @return [Integer | Integer, OpenNebula::User]
    # @example Examples
    #   Success:                    777
    #       Object set to true:     777, OpenNebula::User(777)
    #   Error:                      "[one.user.allocation] Error ...", maybe caused if user with given name already exists
    #   Error:                      0
    def UserCreate(login, pass, groupid = nil, client = $client, object = false)
        id = id_gen()
        LOG_CALL(id, true)
        defer { LOG_CALL(id, false, 'UserCreate') }
        user = User.new(User.build_xml(0), client) # Generates user template using oneadmin user object
        groupid = nil
        begin
            allocation_result = user.allocate(login, pass, "core", groupid.nil? ? [USERS_GROUP] : [USERS_GROUP, groupid]) # Создание и размещение в пул нового пользователя login:pass
        rescue => e
            raise e.message
            return 0
        end
    
        LOG allocation_result.message, 'DEBUG' if !allocation_result.nil? # В случае неудачного размещения будет ошибка, при удачном nil
        return user.id, user if object
        return user.id
    end
    # Creates VM for Old OpenNebula account and with old IP address
    # @param [Hash] params - all needed data for VM reinstall
    # @option params [Integer] :vmid - VirtualMachine for Reinstall ID
    # @option params [Integer] :userid - new Virtual Machine owner
    # @option params [String] :passwd Password for new Virtual Machine 
    # @option params [Integer] :templateid - templateid for Instantiate
    # @option params [Integer] :cpu vCPU cores amount for new VM
    # @option params [Integer] :iops IOPS limit for new VM's drive 
    # @option params [String] :units Units for RAM and drive size, can be 'MB' or 'GB'
    # @option params [Integer] :ram RAM size for new VM
    # @option params [Integer] :drive Drive size for new VM
    # @option params [String] :ds_type VM deplot target datastore drives type, 'SSD' ot 'HDD'
    # @option params [Bool] :release (false) VM will be started on HOLD if false
    # @param [Array<String>] trace - public trace log
    # @return [Hash, nil, String] 
    # @example Example out
    #   Success: { 'vmid' => 124, 'vmid_old' => 123, 'ip' => '0.0.0.0', 'ip_old' => '0.0.0.0' }
    #   Some params not given: String('ReinstallError - some params are nil')
    #   Debug turn method off: nil
    #   Debug return fake data: { 'vmid' => rand(params['vmid'].to_i + 1000), 'vmid_old' => params['vmid'], 'ip' => '0.0.0.0', 'ip_old' => '0.0.0.0' } 
    def Reinstall(params, trace = ["Reinstall method called:#{__LINE__}"])
        LOG_STAT()
        id = id_gen()
        LOG_CALL(id, true)
        defer { LOG_CALL(id, false, 'Reinstall') }
        begin
            # Сделать проверку на корректность присланных данных: существует ли юзер, существует ли ВМ
            LOG params.merge!({ :method => 'Reinstall' }).debug_out, 'DEBUG'
            return nil if params['debug'] == 'turn_method_off'
            return { 'vmid' => rand(params['vmid'].to_i + 1000), 'vmid_old' => params['vmid'], 'ip' => '0.0.0.0', 'ip_old' => '0.0.0.0' } if params['debug'] == 'data'   

            LOG "Reinstalling VM#{params['vmid']}", 'Reinstall'
            trace << "Checking params:#{__LINE__ + 1}"
            params['vmid'], params['groupid'], params['userid'], params['templateid'] = params['vmid'].to_i, params['groupid'].to_i, params['userid'].to_i, params['templateid'].to_i

            if params['vmid'] * params['groupid'] * params['userid'] * params['templateid'] == 0 then
                LOG "ReinstallError - some params are nil", 'Reinstall'
                return "ReinstallError - some params are nil"
            end

            LOG 'Initializing vm object', 'DEBUG'
            trace << "Initializing old VM onject:#{__LINE__ + 1}"            
            vm = onblock(VirtualMachine, params['vmid'])
            LOG 'Collecting data from old template', 'DEBUG'
            trace << "Collecting data from old template:#{__LINE__ + 1}"            
            nic, context = vm.info! || vm.to_hash['VM']['TEMPLATE']['NIC'], vm.to_hash['VM']['TEMPLATE']['CONTEXT']
            
            LOG 'Initializing template obj'
            LOG 'Generating new template', 'DEBUG'
            trace << "Generating NIC context:#{__LINE__ + 1}"
            context = "NIC = [\n\tIP=\"#{nic['IP']}\",\n\tDNS=\"#{nic['DNS']}\",\n\tGATEWAY=\"#{nic['GATEWAY']}\",\n\tNETWORK=\"#{nic['NETWORK']}\",\n\tNETWORK_UNAME=\"#{nic['NETWORK_UNAME']}\"\n]\n"
            trace << "Generating template object:#{__LINE__ + 1}"            
            template = onblock(Template, params['templateid'])
            template.info!
            trace << "Checking OS type:#{__LINE__ + 1}"            
            win = template.win?
            trace << "Generating credentials and network context:#{__LINE__ + 1}"
            context += "CONTEXT = [\n\tPASSWORD=\"#{params['passwd']}\",\n\tETH0_IP=\"#{nic['IP']}\",\n\tETH0_GATEWAY=\"#{nic['GATEWAY']}\",\n\tETH0_DNS=\"#{nic['DNS']}\",\n\tNETWORK=\"YES\"#{ win ? ', USERNAME = "Administrator"' : nil}\n]\n"
            trace << "Generating specs configuration:#{__LINE__ + 1}"
            context += "VCPU=\"#{params['cpu']}\"\nMEMORY=\"#{params['ram'] * (params['units'] == 'GB' ? 1024 : 1)}\""
            context += "DISK=[\n\tIMAGE_ID = \"#{template.to_hash['VMTEMPLATE']['TEMPLATE']['DISK']['IMAGE_ID']}\",\n\tSIZE=\"#{params['drive'] * (params['units'] == 'GB' ? 1024 : 1)}\",\n\tOPENNEBULA_MANAGED = \"NO\"]"
            LOG "Resulting template:\n#{context}", 'DEBUG'
            
            trace << "Terminating VM:#{__LINE__ + 1}"            
            vm.terminate(true)
            LOG 'Waiting until terminate process will over', 'Reinstall'
            trace << ":#{__LINE__ + 1}"            
            until STATE_STR(params['vmid']) == 'DONE' do
                sleep(0.2)
            end if params['release']
            LOG 'Creating new VM', 'DEBUG'
            trace << "Instantiating template:#{__LINE__ + 1}"
            vmid = template.instantiate(params['login'] + '_vm', false, context)
            
            begin    
                if vmid.class != Fixnum && vmid.include?('IP/MAC') then
                    trace << "Retrying template instantiation:#{__LINE__ + 1}"                
                    sleep(3)
                    vmid = template.instantiate(params['login'] + '_vm', false, context)
                end
            rescue => e
                return vmid, vmid.class, vmid.message if vmid.class != Fixnum
                return vmid, vmid.class
            end           

            return vmid.message if vmid.class != Fixnum

            trace << "Changing VM owner:#{__LINE__ + 1}"
            onblock(:vm, vmid).chown(params['userid'], USERS_GROUP)

            #####   PostDeploy Activity define   #####
            Thread.new do

                host = params['host'].nil? ? $default_host : params['host']

                LOG 'Deploying VM to the host', 'DEBUG'
                onblock(:vm, vmid) do | vm |
                    vm.deploy(host, false, ChooseDS(params['ds_type'])) if params['release']
                end

                LOG 'Waiting until VM will be deployed', 'DEBUG'
                until STATE(vmid) == 3 && LCM_STATE(vmid) == 3 do
                    sleep(30)
                end

                postDeploy = PostDeployActivities.new

                #LimitsController

                LOG "Executing LimitsController for VM#{vmid} | Cluster type: #{ClusterType(host)}", 'DEBUG'
                trace << "Executing LimitsController for VM#{vmid} | Cluster type: #{ClusterType(host)}:#{__LINE__ + 1}"
                postDeploy.LimitsController(params, vmid)

                #endLimitsController
                #TrialController
                if params['trial'] then
                    trace << "Creating trial counter thread:#{__LINE__ + 1}"
                    postDeploy.TrialController(vmid)
                end
                #endTrialController
                #AnsibleController
                
                if params['ansible'] && params['release'] then
                    trace << "Creating Ansible Installer thread:#{__LINE__ + 1}"
                    postDeploy.AnsibleController(params, vmid)
                end

                #endAnsibleController

            end if params['release']
            ##### PostDeploy Activity define END #####

            return { 'vmid' => vmid, 'vmid_old' => params['vmid'], 'ip' => GetIP(vmid), 'ip_old' => nic['IP'] }
        rescue => e
            return e.message, trace
        end
    end
    # Creates new virtual machine from the given OS template and resize it to given specs, and new user account, which becomes owner of this VM 
    # @param [Hash] params - all needed data for new User and VM creation
    # @option params [String] :login Username for new OpenNebula account
    # @option params [String] :password Password for new OpenNebula account
    # @option params [String] :passwd Password for new Virtual Machine 
    # @option params [Integer] :templateid Template ID to instantiate
    # @option params [Integer] :cpu vCPU cores amount for new VM
    # @option params [Integer] :iops IOPS limit for new VM's drive 
    # @option params [String] :units Units for RAM and drive size, can be 'MB' or 'GB'
    # @option params [Integer] :ram RAM size for new VM
    # @option params [Integer] :drive Drive size for new VM
    # @option params [String] :ds_type VM deplot target datastore drives type, 'SSD' or 'HDD'
    # @option params [Integer] :groupid Additional group, in which user should be
    # @option params [Boolean] :trial (false) VM will be suspended after TRIAL_SUSPEND_DELAY
    # @option params [Boolean] :release (false) VM will be started on HOLD if false
    # @option params [String]  :user-template Addon template, you may append to default template(Use XML-string as OpenNebula requires)
    # @param [Array<String>] trace - public trace log
    # @return [Hash, nil] UserID, VMID and IP address if success, or error message and traceback log if error
    # @example Example out
    #   Success: {'userid' => 777, 'vmid' => 123, 'ip' => '0.0.0.0'}
    #   Debug is set to true: nil
    #   Template not found Error: {'error' => "TemplateLoadError", 'trace' => (trace << "TemplateLoadError:#{__LINE__ - 1}")(Array<String>)}
    #   User create Error: {'error' => "UserAllocateError", 'trace' => trace(Array<String>)}
    #   Unknown error: { 'error' => e.message, 'trace' => trace(Array<String>)} 
    def CreateVMwithSpecs(params, trace = ["#{__method__.to_s} method called:#{__LINE__}"])
        LOG_STAT()
        LOG_CALL(id = id_gen(), true, __method__)
        defer { LOG_CALL(id, false, 'CreateVMwithSpecs') }
        LOG params.merge!(:method => __method__.to_s).debug_out, 'DEBUG'
        # return
        begin
            trace << "Checking params types:#{__LINE__ + 1}"
            params['cpu'], params['ram'], params['drive'], params['iops'] = params['cpu'].to_i, params['ram'].to_i, params['drive'].to_i, params['iops'].to_i

            ###################### Doing some important system stuff ###############################################################
            
            return nil if DEBUG
            LOG_TEST "CreateVMwithSpecs for #{params['login']} Order Accepted! #{params['trial'] == true ? "VM is Trial" : nil}" # Логи
            
            LOG_TEST "Params: #{params.inspect}" if DEBUG # Логи
            
            trace << "Checking template:#{__LINE__ + 1}"
            onblock(:t, params['templateid']) do | t |
                result = t.info!
                if params['templateid'] == 0 || result != nil then
                    LOG_TEST "Error: TemplateLoadError"
                    return {'error' => "TemplateLoadError", 'trace' => (trace << "TemplateLoadError:#{__LINE__ - 1}")}
                end
            end
            
            #####################################################################################################################
            
            #####   Initializing useful variables   #####
            userid, vmid = 0, 0
            ##### Initializing useful variables END #####
            
            
            #####   Creating new User   #####
            LOG_TEST "Creating new user for #{params['login']}"
            if params['nouser'].nil? || !params['nouser'] then
                trace << "Creating new user:#{__LINE__ + 1}"
                userid, user = UserCreate(params['login'], params['password'], params['groupid'].to_i, @client, true) if params['test'].nil?
                LOG_TEST "Error: UserAllocateError" if userid == 0
                trace << "UserAllocateError:#{__LINE__ - 2}" if userid == 0
                return {'error' => "UserAllocateError", 'trace' => trace} if userid == 0
            else
                userid, user = params['userid'], onblock(:u, params['userid'])
            end
            ##### Creating new User END #####
            
            #####   Creating and Configuring VM   #####
            LOG_TEST "Creating VM for #{params['login']}"
            trace << "Creating new VM:#{__LINE__ + 1}"
            onblock(:t, params['templateid']) do | t |
                t.info!
                specs = "VCPU = #{params['cpu']}
                MEMORY = #{params['ram'] * (params['units'] == 'GB' ? 1024 : 1)}
                DISK = [
                    IMAGE_ID = \"#{t.to_hash['VMTEMPLATE']['TEMPLATE']['DISK']['IMAGE_ID']}\",
                    SIZE = \"#{params['drive'] * (params['units'] == 'GB' ? 1024 : 1)}\",
                    OPENNEBULA_MANAGED = \"NO\"]"
                vmid = t.instantiate("#{params['login']}_vm", true, specs + "\n" + params['user-template'].to_s)
            end

            raise "Template instantiate Error: #{vmid.message}" if vmid.class != Fixnum

            trace << "Updating user quota:#{__LINE__ + 1}"
            user.update_quota_by_vm(
                'append' => true, 'cpu' => params['cpu'],
                'ram' => params['ram'] * (params['units'] == 'GB' ? 1024 : 1),
                'drive' => params['drive'] * (params['units'] == 'GB' ? 1024 : 1)
            )
            LOG_TEST "New User account created"
            
            host = params['host'].nil? ? $default_host : params['host']

            LOG_TEST 'Configuring VM Template'
            trace << "Configuring VM Template:#{__LINE__ + 1}"            
            onblock(:vm, vmid) do | vm |
                trace << "Changing VM owner:#{__LINE__ + 1}"
                begin
                    vm.chown(userid, USERS_GROUP)
                rescue
                    LOG "CHOWN error, params: #{userid}, #{vm}", 'DEBUG'
                end
                win = onblock(:t, params['templateid']).win?
                LOG "Instantiating VM as#{win ? nil : ' not'} Windows", 'DEBUG'
                trace << "Setting VM context:#{__LINE__ + 2}"
                begin
                    vm.updateconf(
                        "CONTEXT = [ NETWORK=\"YES\", PASSWORD = \"#{params['passwd']}\", SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\"#{ win ? ', USERNAME = "Administrator"' : nil} ]"
                    )
                rescue => e
                    LOG "Context configuring error: #{e.message}", 'DEBUG'
                end
                    
                trace << "Setting VM VNC settings:#{__LINE__ + 2}"
                begin
                    vm.updateconf(
                        "GRAPHICS = [ LISTEN=\"0.0.0.0\", PORT=\"#{(CONF['OpenNebula']['base-vnc-port'] + vmid).to_s}\", TYPE=\"VNC\" ]"
                    ) # Configuring VNC
                rescue => e
                    LOG "VNC configuring error: #{e.message}", 'DEBUG'
                end

                trace << "Deploying VM:#{__LINE__ + 1}"            
                vm.deploy($default_host, false, ChooseDS(params['ds_type'])) if params['release']
                # vm.deploy($default_host, false, params['datastore'].nil? ? ChooseDS(params['ds_type']): params['datastore']) if params['release']
            end
            ##### Creating and Configuring VM END #####            

            #####   PostDeploy Activity define   #####
            Thread.new do

                onblock(:vm, vmid).wait_for_state

                postDeploy = PostDeployActivities.new

                #LimitsController

                LOG "Executing LimitsController for VM#{vmid} | Cluster type: #{ClusterType(host)}", 'DEBUG'
                trace << "Executing LimitsController for VM#{vmid} | Cluster type: #{ClusterType(host)}:#{__LINE__ + 1}"
                postDeploy.LimitsController(params, vmid)

                #endLimitsController
                #TrialController

                if params['trial'] then
                    trace << "Creating trial counter thread:#{__LINE__ + 1}"
                    postDeploy.TrialController(params, vmid)
                end

                #endTrialController
                #AnsibleController

                if params['ansible'] && params['release'] then
                    trace << "Creating Ansible Installer thread:#{__LINE__ + 1}"
                    postDeploy.AnsibleController(params, vmid)
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
    class PostDeployActivities
        include Deferable
        def AnsibleController(params, vmid)
            LOG_CALL(id = id_gen(), true, __method__)
            Thread.new do
                onblock(:vm, vmid).wait_for_state
                sleep(60)
                AnsibleController(params.merge({
                    'super' => '', 'host' => "#{GetIP(vmid)}:#{CONF['OpenNebula']['users-vms-ssh-port']}", 'vmid' => vmid
                }))
            end
            LOG "Install-thread started, you should wait until the #{params['ansible-service']} will be installed", 'AnsibleController'
            LOG_CALL(id, false, 'AnsibleController')
        end
        def LimitsController(params, vmid)
            LOG_CALL(id = id_gen(), true, __method__)
            defer { LOG_CALL(id, false, 'LimitsController') }
            onblock(:vm, vmid) do | vm |
                lim_res = vm.setResourcesAllocationLimits(
                    cpu: params['cpu'] * CONF['vCenter']['cpu-limits-koef'], ram: params['ram'] * (params['units'] == 'GB' ? 1024 : 1), iops: params['iops']
                )
                if !lim_res.nil? then
                    LOG "Limits was not set, error: #{lim_res}", 'DEBUG'
                end
            end if ClusterType(host) == 'vcenter'
        end
        def TrialController(params, vmid)
            LOG_CALL(id = id_gen(), true, __method__)        
            LOG "VM #{vmid} suspend action scheduled", 'TrialController'
            action_time = Time.now.to_i + ( params['trial-suspend-delay'].nil? ?
                                TRIAL_SUSPEND_DELAY :
                                params['trial-suspend-delay'] )
            onblock(:vm, vmid).schedule('suspend', action_time)
            LOG_CALL(id, false, 'TrialController')
        end
    
        deferable :LimitsController
    end
end
