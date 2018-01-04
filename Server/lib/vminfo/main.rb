########################################################
#   Методы для получения информации о ВМ и Аккаунтах   #
########################################################

puts 'Extending Handler class by VM and User info getters'
class WHMHandler
    def VM_XML(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = get_pool_element(VirtualMachine, vmid, @client)
        return vm.info! || vm.to_xml
    end
    def activity_log()
        LOG_STAT(__method__.to_s, time())        
        LOG "Log file content has been copied remotely", "activity_log"
        log = File.read("#{ROOT}/log/activities.log")
        return log
    end
    
    def log(msg)
        LOG_STAT(__method__.to_s, time())        
        LOG(msg, "log")
	    return "YEP!"
    end
    def GetIP(vmid)
        LOG_STAT(__method__.to_s, time())
        onblock('vm', vmid, @client) do |vm|
            vm.info!
            vm = vm.to_hash['VM']
            begin
                return vm['TEMPLATE']['NIC']['IP'] || print( 'nic')
            rescue
                return vm['MONITORING']['GUEST_IP'] if !vm['MONITORING']['GUEST_IP'].nil? && !vm['MONITORING']['GUEST_IP'].include?(':')
            end
            return nil
        end
    end
    def STATE(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = get_pool_element(VirtualMachine, vmid.to_i, @client)
        return vm.info! || vm.state
    end
    def STATE_STR(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = get_pool_element(VirtualMachine, vmid.to_i, @client)
        return vm.info! || vm.state_str
    end
    def LCM_STATE(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = get_pool_element(VirtualMachine, vmid.to_i, @client)
        return vm.info! || vm.lcm_state
    end
    def LCM_STATE_STR(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = get_pool_element(VirtualMachine, vmid.to_i, @client)
        return vm.info! || vm.lcm_state_str
    end
    def get_vm_data(vmid)
        proc_id = proc_id_gen(__method__)
        def get_host(vmid)
            host_pool = HostPool.new(@client)
            host_pool.info!
            host_pool.each do |host|
                host.info!
                return host.name if host.to_hash['HOST']['VMS']['ID'].include? vmid.to_s
            end
        end
        onblock('vm', vmid, @client) do | vm |
            vm.info!
            vm_hash = vm.to_hash['VM']
            return kill_proc(proc_id) || {
                'NAME' => vm_hash['NAME'], 'OWNER' => vm_hash['UNAME'], 'OWNERID' => vm_hash['UID'],
                'IP' => GetIP(vmid), 'HOST' => get_host(vmid), 'STATE' => LCM_STATE(vmid) != 0 ? LCM_STATE_STR(vmid) : STATE_STR(vmid),
                'CPU' => vm_hash['TEMPLATE']['VCPU'], 'RAM' => vm_hash['TEMPLATE']['MEMORY'],
                'IMPORTED' => vm_hash['TEMPLATE']['IMPORTED'].nil? ? 'NO' : 'YES'
            }
        end
    end
    def compare_info
        LOG_STAT(__method__.to_s, time())
        proc_id, info, $free = proc_id_gen(__method__), "Method-inside error", nil
        $proc << "#{__metod__.to_s}_#{proc_id}"        
        def get_lease(vn)
            vn = get_pool_element(VirtualNetwork, vn['ID'].to_i, @client)
            vn = (vn.info! || vn.to_hash)["VNET"]["AR_POOL"]["AR"]
            pool = ((vn["IP"].split('.').last.to_i)..(vn["IP"].split('.').last.to_i + vn["SIZE"].to_i)).to_a.map! { |item| vn['IP'].split('.').slice(0..2).join('.') + "." + item.to_s }
            vn['LEASES']['LEASE'].each do | addr |
                pool.delete addr
            end if !vn['LEASES']['LEASE'].nil?
            $free.push pool
        end
        def get_ip(vm)
            begin
                return vm['TEMPLATE']['NIC']['IP'] || print( 'nic')
            rescue
                return vm['MONITORING']['GUEST_IP'] if !vm['MONITORING']['GUEST_IP'].nil? && !vm['MONITORING']['GUEST_IP'].include?(':')
            end
            return nil
        end
        
        vm_pool, info = VirtualMachinePool.new(@client), []
        vm_pool.info_all!
        vm_pool.each do |vm|
            break if vm.nil?
            vm = vm.to_hash['VM']
            info << {
                :vmid => vm['ID'], :userid => vm['UID'],
                :login => vm['UNAME'], :ip => get_ip(vm)
            }
        end
        vn_pool, $free = VirtualNetworkPool.new(@client), []
        vn_pool = vn_pool.info_all! + vn_pool.to_hash['VNET_POOL']['VNET']
        vn_pool.each do | vn |
            break if vn.nil?
            get_lease vn
        end if vn_pool.class == Array
        get_lease vn_pool if vn_pool.class == Hash  
        return kill_proc(proc_id) || info, $free 
    end
    def GetUserInfo(userid)
        user = get_pool_element(User, userid, @client)
        LOG_STAT(__method__.to_s, time())
        return user.info! || user.to_xml
    end
    def proc
        return $proc
    end
end