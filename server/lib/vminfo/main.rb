########################################################
#   Методы для получения информации о ВМ и Аккаунтах   #
########################################################

puts 'Extending Handler class by VM and User info getters'
class IONe
    # Returns VM template XML
    # @param [Integer] vmid - VM ID
    # @return [String] XML
    def VM_XML(vmid)
        LOG_STAT()        
        vm = onblock(VirtualMachine, vmid)
        return vm.info! || vm.to_xml
    end
    # Returns VM's IP by ID
    # @param [Integer] vmid - VM ID
    # @return [String] IP
    def GetIP(vmid)
        LOG_STAT()
        onblock(:vm, vmid) do |vm|
            vm.info!
            vm, ip = vm.to_hash['VM'], 'nil'
            begin
                # If VM was created using OpenNebula template
                ip = vm['TEMPLATE']['NIC']['IP'] if !vm['TEMPLATE']['NIC']['IP'].nil?
            rescue # If not, this action will raise HashRead exception
            end
            begin
                # If VM was imported correctly, IP address will be readed by the monitoring system
                ip = vm['MONITORING']['GUEST_IP'] if !vm['MONITORING']['GUEST_IP'].nil? && !vm['MONITORING']['GUEST_IP'].include?(':')
                # Monitoring can read IPv6 address, so let us make the check
            rescue
            end
            begin
                # Also IP can be stored at the another place in monitoring, but here all IP's are stored 
                ip = vm['MONITORING']['GUEST_IP_ADDRESSES'].split(',').first if !vm['MONITORING']['GUEST_IP_ADDRESSES'].nil?
            rescue
            end
            return 'nil' if ip.nil? || ip.include?(':')
            return ip if !ip.include?(':')
        end
    end
    # Getting VM ID by IP
    # @param [String] ip - IP address
    # @return [Integer | nil] - VM ID if found, nil if not
    def GetVMIDbyIP(ip)
        vm_pool = VirtualMachinePool.new(@client)
        vm_pool.info_all!
        vm_pool.each do |vm| # Прочесываем пул, пока не найдем ВМ с IP равным заданному
            break if nil
            begin
                return vm.id if ip.chomp == GetIP(vm.id).chomp
            rescue
            end
        end
        return nil
    end
    # Getting VM state number by ID
    # @param [Integer] vmid - VM ID
    # @return [Integer] State
    def STATE(vmid) 
        LOG_STAT()        
        vm = onblock(:vm, vmid.to_i)
        return vm.info! || vm.state
    end
    # Getting VM state string by ID
    # @param [Integer] vmid - VM ID
    # @return [String] State
    def STATE_STR(vmid)
        LOG_STAT()        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.state_str
    end
    # Getting VM LCM state number by ID
    # @param [Integer] vmid - VM ID
    # @return [Integer] State
    def LCM_STATE(vmid)
        LOG_STAT()        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.lcm_state
    end
    # Getting VM LCM state string by ID
    # @param [Integer] vmid - VM ID
    # @return [String] State
    def LCM_STATE_STR(vmid)
        LOG_STAT()        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.lcm_state_str
    end
    # Getting VM most important data
    # @param [Integer] vmid - VM ID
    # @return [Hash] Data(name, owner-name, owner-id, ip, host, state, cpu, ram, imported)
    def get_vm_data(vmid)
        proc_id = proc_id_gen(__method__)
        onblock(:vm, vmid) do | vm |
            vm.info!
            vm_hash = vm.to_hash['VM']
            return kill_proc(proc_id) || {
                # "Имя, владелец, id владельца машины"
                'NAME' => vm_hash['NAME'], 'OWNER' => vm_hash['UNAME'], 'OWNERID' => vm_hash['UID'],
                # IP, кластер и упрощенное состояние ВМ
                'IP' => GetIP(vmid), 'HOST' => get_vm_host(vmid), 'STATE' => LCM_STATE(vmid) != 0 ? LCM_STATE_STR(vmid) : STATE_STR(vmid),
                # Технические характеристики ВМ
                'CPU' => vm_hash['TEMPLATE']['VCPU'], 'RAM' => vm_hash['TEMPLATE']['MEMORY'],
                # Данные об истории появления ВМ
                'IMPORTED' => vm_hash['TEMPLATE']['IMPORTED'].nil? ? 'NO' : 'YES'
            }
        end if vmid.class != VirtualMachine # Если приходит vmid
        vm, vmid = vmid, vmid.id # Если приходит объект
        vm_hash = vm.to_hash['VM']
        return kill_proc(proc_id) || {
            'NAME' => vm_hash['NAME'], 'OWNER' => vm_hash['UNAME'], 'OWNERID' => vm_hash['UID'],
            'IP' => GetIP(vmid), 'HOST' => get_vm_host(vmid), 'STATE' => LCM_STATE(vmid) != 0 ? LCM_STATE_STR(vmid) : STATE_STR(vmid),
            'CPU' => vm_hash['TEMPLATE']['VCPU'], 'RAM' => vm_hash['TEMPLATE']['MEMORY'],
            'IMPORTED' => vm_hash['TEMPLATE']['IMPORTED'].nil? ? 'NO' : 'YES'
        }
    end
    # Getting snapshot list for given VM
    # @param [Integer] vmid - VM ID
    # @return [Array<Hash> | Hash]
    def GetSnapshotList(vmid)
        LOG_STAT()        
        return onblock(VirtualMachine, vmid).list_snapshots
    end
end