########################################################
#           Getters for VM's and Users info            #
########################################################

puts 'Extending Handler class by VM and User info getters'
class IONe
    # Returns VM template XML
    # @param [Integer] vmid - VM ID
    # @return [String] XML
    def VM_XML(vmid)
        LOG_STAT()
        LOG_STAT()
        id = id_gen()
        LOG_CALL(id, true, __method__)
        defer { LOG_CALL(id, false, 'VM_XML') }
        vm = onblock(VirtualMachine, vmid)
        vm.info! || vm.to_xml
    end
    # Returns VM's IP by ID
    # @param [Integer] vmid - VM ID
    # @return [String] IP !!!!!!!!!!
    def GetIP(vm_ref)
        vm = case vm_ref
             when OpenNebula::VirtualMachine
                vm_ref.to_hash
             when Fixnum, String
                onblock(:vm, vm_ref).to_hash!
             when Hash
                vm_ref
             end['VM']
        begin
            # If VM was created using OpenNebula template
            ip = IPAddr.new vm['TEMPLATE']['NIC']['IP']
            return ip.to_s if ip.ipv4? && !ip.local?
        rescue # If not, this action will raise HashRead exception
        end
        begin
            # Also IP can be stored at the another place in monitoring, but here all IP's are stored 
            ips = vm['MONITORING']['GUEST_IP_ADDRESSES'].split(',').map! { |ip| IPAddr.new ip }
            return ips.detect { |ip| ip.ipv4? && !ip.local? }.to_s
        rescue
        end
        begin
            # If VM was imported correctly, IP address will be readed by the monitoring system
            ip = IPAddr.new vm['MONITORING']['GUEST_IP']
            # Monitoring can read IPv6 address, so let us make the check
            return ip.to_s if ip.ipv4? && !ip.local?
        rescue
        end
        return ""
    end
    # Getting VM ID by IP
    # @param [String] ip - IP address
    # @return [Integer | nil] - VM ID if found, nil if not
    def GetVMIDbyIP(ip)
        LOG_STAT()
        id = id_gen()
        LOG_CALL(id, true, __method__)
        defer { LOG_CALL(id, false, 'GetVMIDbyIP') }
        vm_pool = VirtualMachinePool.new(@client)
        vm_pool.info_all!
        vm_pool.each do |vm|
            break if nil
            begin
                return vm.id if ip.chomp == GetIP(vm.id).chomp
            rescue
            end
        end
        nil
    end
    # Getting VM state number by ID
    # @param [Integer] vmid - VM ID
    # @return [Integer] State
    def STATE(vmid) 
        onblock(:vm, vmid.to_i).state!
    end
    # Getting VM state string by ID
    # @param [Integer] vmid - VM ID
    # @return [String] State
    def STATE_STR(vmid)
        onblock(:vm, vmid.to_i).state_str!
    end
    # Getting VM LCM state number by ID
    # @param [Integer] vmid - VM ID
    # @return [Integer] State
    def LCM_STATE(vmid)
        onblock(:vm, vmid.to_i).lcm_state!
    end
    # Getting VM LCM state string by ID
    # @param [Integer] vmid - VM ID
    # @return [String] State
    def LCM_STATE_STR(vmid)
        onblock(:vm, vmid.to_i).lcm_state_str!
    end
    # Getting VM most important data
    # @param [Integer] vmid - VM ID
    # @return [Hash] Data(name, owner-name, owner-id, ip, host, state, cpu, ram, imported)
    def get_vm_data(vmid)
        onblock(:vm, vmid) do | vm |
            vm.info!
            vm_hash = vm.to_hash['VM']
            return {
                # "Name, owner, owner id"
                'NAME' => vm_hash['NAME'], 'OWNER' => vm_hash['UNAME'], 'OWNERID' => vm_hash['UID'],
                # IP, host and vm state
                'IP' => GetIP(vmid), 'HOST' => get_vm_host(vmid), 'STATE' => LCM_STATE(vmid) != 0 ? LCM_STATE_STR(vmid) : STATE_STR(vmid),
                # VM specs
                'CPU' => vm_hash['TEMPLATE']['VCPU'], 'RAM' => vm_hash['TEMPLATE']['MEMORY'],
                # VM creation hist
                'IMPORTED' => vm_hash['TEMPLATE']['IMPORTED'].nil? ? 'NO' : 'YES'
            }
        end if vmid.class != VirtualMachine # if vmid
        vm, vmid = vmid, vmid.id # if vm object
        vm_hash = vm.to_hash['VM']
        {
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
        id = id_gen()
        LOG_CALL(id, true, __method__)
        defer { LOG_CALL(id, false, 'GetSnapshotList') }
             
        onblock(VirtualMachine, vmid).list_snapshots
    end
end