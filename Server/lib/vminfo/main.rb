########################################################
#   Методы для получения информации о ВМ и Аккаунтах   #
########################################################

puts 'Extending Handler class by VM and User info getters'
class WHMHandler
    def VM_XML(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid)
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
        onblock('vm', vmid) do |vm|
            vm.info!
            vm, ip = vm.to_hash['VM'], 'nil'
            begin
                ip = vm['TEMPLATE']['NIC']['IP'] if !vm['TEMPLATE']['NIC']['IP'].nil?
            rescue
            end
            begin
                ip = vm['MONITORING']['GUEST_IP'] if !vm['MONITORING']['GUEST_IP'].nil? && !vm['MONITORING']['GUEST_IP'].include?(':')
            rescue
            end
            begin
                ip = vm['MONITORING']['GUEST_IP_ADDRESSES'].split(',').first if !vm['MONITORING']['GUEST_IP_ADDRESSES'].nil?
            rescue
            end
            return 'nil' if ip.nil? || ip.include?(':')
            return ip if !ip.include?(':')
        end
    end
    def GetVMIDbyIP(ip)
        vm_pool = VirtualMachinePool.new(@client)
        vm_pool.info_all!
        vm_pool.each do |vm|
            break if nil
            begin
                return vm.id if ip.chomp == GetIP(vm.id).chomp
            rescue
            end
        end
        return nil
    end
    def STATE(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.state
    end
    def STATE_STR(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.state_str
    end
    def LCM_STATE(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.lcm_state
    end
    def LCM_STATE_STR(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.lcm_state_str
    end
    def get_vm_data(vmid)
        proc_id = proc_id_gen(__method__)
        onblock('vm', vmid) do | vm |
            vm.info!
            vm_hash = vm.to_hash['VM']
            return kill_proc(proc_id) || {
                'NAME' => vm_hash['NAME'], 'OWNER' => vm_hash['UNAME'], 'OWNERID' => vm_hash['UID'],
                'IP' => GetIP(vmid), 'HOST' => get_vm_host(vmid), 'STATE' => LCM_STATE(vmid) != 0 ? LCM_STATE_STR(vmid) : STATE_STR(vmid),
                'CPU' => vm_hash['TEMPLATE']['VCPU'], 'RAM' => vm_hash['TEMPLATE']['MEMORY'],
                'IMPORTED' => vm_hash['TEMPLATE']['IMPORTED'].nil? ? 'NO' : 'YES'
            }
        end
    end
    def get_vm_host(vmid)
        onblock('vm', vmid, $client) do | vm |
            vm.info!
            vm = vm.to_hash['VM']["HISTORY_RECORDS"]['HISTORY']
            return vm.last['HOSTNAME'] if vm.class == Array
            return vm['HOSTNAME'] if vm.class == Hash
            return nil
        end
    end
    def compare_info
        LOG_STAT(__method__.to_s, time())
        proc_id, info, $free = proc_id_gen(__method__), "Method-inside error", nil
        def get_lease(vn)
            vn = (vn.info! || vn.to_hash)["VNET"]["AR_POOL"]["AR"][0]
            return if (vn['IP'] && vn['SIZE']).nil?
            pool = ((vn["IP"].split('.').last.to_i)..(vn["IP"].split('.').last.to_i + vn["SIZE"].to_i)).to_a.map! { |item| vn['IP'].split('.').slice(0..2).join('.') + "." + item.to_s }
            leases = vn['LEASES']['LEASE'].map {|lease| lease['IP']}
            vn['LEASES']['LEASE'].each do | lease |
                pool.delete(lease['IP'])
            end
            $free.push pool
        end
        
        vm_pool, info = VirtualMachinePool.new(@client), []
        vm_pool.info_all!
        vm_pool.each do |vm|
            break if vm.nil?
            vm = vm.to_hash['VM']
            info << {
                :vmid => vm['ID'], :userid => vm['UID'], :host => get_vm_host(vm['ID']),
                :login => vm['UNAME'], :ip => GetIP(vm['ID'])
            }
        end
        vn_pool, $free = VirtualNetworkPool.new(@client), []
        vn_pool.info_all!
        vn_pool.each do | vn |
            break if vn.nil?
            begin
                get_lease vn
            rescue
            end
        end
        return kill_proc(proc_id) || info, $free 
    end
    def GetUserInfo(userid)
        user = onblock(User, userid)
        LOG_STAT(__method__.to_s, time())
        return user.info! || user.to_xml
    end
    def proc
        return $proc
    end
end