class IONe
    # Logs sent message into activities.log and gives data about availability
    # @param [String] msg - message to log
    # @return [String('DONE') | String('PONG')]
    # @example
    #   ZmqJsonRpc::Client.new(uri, 50).Test('PING') => 'PONG' -> Service available
    #                                                => Exception -> Service down
    def Test(msg)
        LOG "Test message received, text: #{msg}", "Test" if msg != 'PING'
        if msg == "PING" then
            return "PONG"
        end
        return "DONE"
    end
    # Returns vmid by owner id
    # @param [Integer] uid - owner id
    # @return [Integer | 'none']
    # @example
    #   => Integer => user and vm found
    #   => 'none'  => no user or now vm exists
    def get_vm_by_uid(uid)
        vmp = VirtualMachinePool.new($client)
        vmp.info_all!
        vmp.each do | vm |
            return vm.id.to_i if vm.uid(false) == uid
        end
        return 'none'
    end
    # Returns user id by username
    # @param [String] name - username
    # @return [Integer| 'none']
    # @example
    #   => Integer => user found
    #   => 'none'  => no user exists
    def get_uid_by_name(name)
        up = UserPool.new($client)
        up.info_all!
        up.each do | u |
            return u.id.to_i if u.name == name
        end
        return 'none'        
    end
    # Returns vmid, userid and VM IP by owner username
    # @param [String] name - username
    # @return [Hash]
    # @example
    #   => {:vmid => Integer, :userid => Integer, :ip => String} => User and VM found
    #   => {:vmid => 'none', :userid => 'none', :ip => String}
    def get_vm_by_uname(name)
        userid = get_uid_by_name(name)
        vmid = get_vm_by_uid(userid)
        return { :vmid => vmid, :userid => userid, :ip => GetIP(vmid) }
    end
    # Returns host name, where VM has been deployed
    # @param [Integer] vmid - VM ID
    # @return [String | nil]
    # @example
    #   => String('example-node-vcenter') => Host was found
    #   => nil => Host wasn't found
    def get_vm_host(vmid) # Получение имени кластера, которому принадлежит ВМ
        onblock(:vm, vmid, $client) do | vm |
            vm.info!
            vm = vm.to_hash['VM']["HISTORY_RECORDS"]['HISTORY'] # Searching hostname at VM allocation history
            return vm.last['HOSTNAME'] if vm.class == Array # If history consists of 2 or more lines - returns last
            return vm['HOSTNAME'] if vm.class == Hash # If history consists of only one line - returns it
            return nil # Returns NilClass if did not found anything - possible if vm is at HOLD or PENDING state
        end
    end
    # Returns VM listing with some additional data, available nodes list and free IP-addresses in AddressPool
    # @param [Array] vms - filter, returns only listed vms
    # @return [Array<Hash>, Array<String>, Array<String> | Array<Hash>, Array<String>]
    # @example VM's filter given
    #       compare_info([1, 2, ...]) => 
    #           [{
    #               :vmid => 1, :userid => 1, :host => 'example-node0',
    #               :login => 'username', :ip => '0.0.0.0', :state => 'RUNNING'
    #           }, ...], ['example-node0', 'example-node1', ...]
    # @example VM's filter not given
    #       compare_info() => 
    #           [{
    #               :vmid => 0, :userid => 0, :host => 'example-node0',
    #               :login => 'username', :ip => '192.168.10.3', :state => 'RUNNING'
    #           }, ...], ['example-node0', 'example-node1', ...], ['192.168.10.2', '192.168.10.4', '192.168.10.5', ...]
    def compare_info(vms = [])
        LOG_STAT()
        proc_id, info, $free = proc_id_gen(__method__), "Method-inside error", nil
        # @!visibility private
        def get_lease(vn) # This functions generates list of free addresses in given VN
            vn = (vn.info! || vn.to_hash)["VNET"]["AR_POOL"]["AR"][0]
            return if (vn['IP'] && vn['SIZE']).nil?
            pool = ((vn["IP"].split('.').last.to_i)..(vn["IP"].split('.').last.to_i + vn["SIZE"].to_i)).to_a.map! { |item| vn['IP'].split('.').slice(0..2).join('.') + "." + item.to_s }
            leases = vn['LEASES']['LEASE'].map {|lease| lease['IP']}
            vn['LEASES']['LEASE'].each do | lease |
                pool.delete(lease['IP'])
            end
            $free.push pool
        end
        
        vm_pool, info = VirtualMachinePool.new($client), []

        vm_pool.info_all!
        vm_pool.each do |vm| # Creating VM list from VirtualMachine Pool Object
            break if vm.nil?
            next if !vms.empty? && !vms.include?(vm.id)
            vm = vm.to_hash['VM']
            info << {
                :vmid => vm['ID'], :userid => vm['UID'], :host => get_vm_host(vm['ID']),
                :login => vm['UNAME'], :ip => GetIP(vm['ID']), :state => (LCM_STATE(vm['ID']) != 0 ? LCM_STATE_STR(vm['ID']) : STATE_STR(vm['ID']))
            }
        end

        host_pool, hosts = HostPool.new($client), [] # Collecting hostnames(node-names) from HostPool
        host_pool.info_all!
        host_pool.each do | host |
            hosts << host.name
        end
        
        return kill_proc(proc_id) || info if !vms.empty?

        vn_pool, $free = VirtualNetworkPool.new(@client), []
        vn_pool.info_all!
        vn_pool.each do | vn | # Getting leases from each VN
            break if vn.nil?
            begin
                get_lease vn
            rescue
            end
        end

        return kill_proc(proc_id) || info, hosts, $free
    end
    # Returns User template in XML
    # @param [Integer] userid
    # @return [String] XML
    def GetUserInfo(userid)
        LOG_STAT()
        onblock(User, userid) do |user|
            user.info!
            return user.to_xml
        end
    end
    # Returns monitoring information about datastores
    # @param [String] type - choose datastores types for listing: system('sys') or image('img')
    # @return [Array<Hash> | String]
    # @example
    #   DatastoresMonitoring('sys') => [{"id"=>101, "name"=>"NASX", "full_size"=>"16TB", "used"=>"3.94TB", "type"=>"HDD", "deploy"=>"TRUE"}, ...]
    #   DatastoresMonitoring('ing') => String("WrongTypeExeption: type 'ing' not exists")
    def DatastoresMonitoring(type) # Мониторинг занятости дисков на NAS*
        LOG_STAT()        
        return "WrongTypeExeption: type '#{type}' not exists" if type != 'sys' && type != 'img'

        def sizeConvert(mb) # Конвертация мегабайт в гига- либо тера- байты
            if mb.to_f / 1024 > 768 then
                return "#{(mb.to_f / 1048576.0).round(2).to_s}TB"
            else
                return "#{(mb.to_f / 1024.0).round(2).to_s}GB" 
            end
        end

        img_pool, mon = DatastorePool.new(@client), []
        img_pool.info_all!
        img_pool.each do | img |
            mon << { 
                'id' => img.id, 'name' => img.name.split('(').first, :full_size => sizeConvert(img.to_hash['DATASTORE']['TOTAL_MB']),
                'used' => sizeConvert(img.to_hash['DATASTORE']['USED_MB']),
                'type' => img.to_hash['DATASTORE']['TEMPLATE']['DRIVE_TYPE'],
                'deploy' => img.to_hash['DATASTORE']['TEMPLATE']['DEPLOY']
            } if img.short_type_str == type && img.id > 2
        end
        return mon
    end
    # Returns monitoring information about nodes
    # @return [Array<Hash>]
    # @example
    #   HostsMonitoring() => {"id"=>0, "name"=>"vCloud", "full_size"=>"875.76GB", "reserved"=>"636.11GB", "running_vms"=>179, "cpu"=>"16.14%"}
    def HostsMonitoring()
        LOG_STAT()        

        def sizeConvert(mb)
            if mb.to_f / 1048576 > 768 then
                return "#{(mb.to_f / 1073741824.0).round(2).to_s}TB"
            else
                return "#{(mb.to_f / 1048576.0).round(2).to_s}GB" 
            end
        end

        host_pool, mon = HostPool.new($client), []
        host_pool.info!
        host_pool.each do | host |
            host = host.to_hash['HOST']
            mon << { 
                :id => host['ID'].to_i, :name => host['NAME'], :full_size => sizeConvert(host.to_hash['HOST_SHARE']['TOTAL_MEM']),
                :reserved => sizeConvert(host.to_hash['HOST_SHARE']['MEM_USAGE']),
                :running_vms => host.to_hash['HOST_SHARE']['RUNNING_VMS'].to_i,
                :cpu => "#{(host.to_hash['HOST_SHARE']['USED_CPU'].to_f / host.to_hash['HOST_SHARE']['TOTAL_CPU'].to_f * 100).round(2).to_s}%"
            }
        end
        return mon
    end
    # @api private
    def getglog
        return $log
    end
end