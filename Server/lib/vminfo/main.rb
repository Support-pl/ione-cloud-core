########################################################
#   Методы для получения информации о ВМ и Аккаунтах   #
########################################################

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
        doc_hash = Nori.new.parse(VM_XML(vmid))
        return doc_hash['VM']['TEMPLATE']['CONTEXT']['ETH0_IP']
    end
    def STATE(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = get_pool_element(VirtualMachine, vmid.to_i, @client)
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.info! || vm.state
    end
    def STATE_STR(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = get_pool_element(VirtualMachine, vmid.to_i, @client)
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.info! || vm.state_str
    end
    def LCM_STATE(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = get_pool_element(VirtualMachine, vmid.to_i, @client)
        # vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.info! || vm.lcm_state
    end
    def LCM_STATE_STR(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = get_pool_element(VirtualMachine, vmid.to_i, @client)
        return vm.info! || vm.lcm_state_str
    end
    def compare_info()
        LOG_STAT(__method__.to_s, time())
        installid = Time.now.to_i.to_s(16).crypt(params['login'])
        $proc << "compare_info#{installid}"
        at_exit do
            $proc.delete "compare_info#{installid}"
        end 
        def get_name(uid)
            return `mysql opennebula -BNe "select name from user_pool where oid = #{uid}"`.chomp
        end
        def getLease(vn)
            vn = get_pool_element(VirtualNetwork, vn['ID'].to_i, @client)
            vn = (vn.info! || vn.to_hash)["VNET"]["AR_POOL"]["AR"]
            pool = ((vn["IP"].split('.').last.to_i)..(vn["IP"].split('.').last.to_i + vn["SIZE"].to_i)).to_a.map! { |item| vn['IP'].split('.').slice(0..2).join('.') + "." + item.to_s }
            vn['LEASES']['LEASE'].each do | addr |
                pool.delete addr
            end if !vn['LEASES']['LEASE'].nil?
            $free.push pool
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
        
        vn_pool, $free = VirtualNetworkPool.new(@client), []
        vn_pool = vn_pool.info_all! || vn_pool.to_hash['VNET_POOL']['VNET']
        vn_pool.each do | vn |
            break if vn.nil?
            getLease vn
        end if vn_pool.class == Array
        getLease vn_pool if vn_pool.class == Hash
        return info, $free
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