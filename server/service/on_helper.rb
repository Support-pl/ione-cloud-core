require 'rbvmomi'

module ONeHelper
    # Alias for RbVmomi::VIM
    VIM = RbVmomi::VIM

    # vcenter-helper funcs, source: https://github.com/MarkArbogast/vsphere-helper/blob/master/lib/vsphere_helper/helpers.rb#L51-#L68
    def recursive_find_vm(folder, name, exact = false)
        def matches(child, name, exact = false)
            is_vm = child.class == RbVmomi::VIM::VirtualMachine
            name_matches = (name == "*") || (exact ? (child.name == name) : (child.name.include? name))
            return is_vm && name_matches
        end
        found = []
        folder.children.each do |child|
          if matches(child, name, exact)
            found << child
          elsif child.class == RbVmomi::VIM::Folder
            found << recursive_find_vm(child, name, exact)
          end
        end
      
        found.flatten
    end


    # {#onblock} supported instances list 
    ON_INSTANCES = {
        :vm => VirtualMachine,
        :t  => Template,
        :h  => Host,
        :u  => User,
        :vn => VirtualNetwork
        }

    # Generates any 'Pool' element object
    # @param [Class] type - object class to create
    # @param [Integer] id - element id at its Pool
    # @param [OpenNebula::Client] client - auth provider object
    # @return [OpenNebula::PoolElement]
    # @example Getting VirtualMachine object
    #   vm = ONeHelper::get_pool_element(VirtualMachine, 777, Client.new('oneadmin:secret', 'http://localhost:2633/RPC2'))
    #   p vm.class
    #       => #<OpenNebula::VirtualMachine:0x00000004c4ead8>
    def get_pool_element(type, id, client)
        return type.new(type.build_xml(id), client)
    end

    # Generates any 'Pool' element object or yields it
    # @param [Class | Symbol] object - object class to create or symbol linked to target class
    # @param [Integer] id - element id at its Pool
    # @param [OpenNebula::Client] client - auth provider object, if 'none' uses global variable '$client'
    # @return [OpenNebula::PoolElement]
    # @example Getting VirtualMachine object
    #   $client = Client.new('oneadmin:secret', 'http://localhost:2633/RPC2')
    #       * * *
    #   vm = onblock :vm, 777
    #   p vm.class
    #       => #<OpenNebula::VirtualMachine:0x00000004c64720>
    # @yield [object] If block is given, onblock yields given object
    # @example Using VirtualMachine object inside block
    #   onblock :vm, 777 do | vm |
    #       vm.info!
    #       puts JSON.pretty_generate(vm.to_hash)
    #   end
    def onblock(object, id, client = 'none')
        client = $client if client == 'none'
        if object.class != Class then
            object = ON_INSTANCES[object]
            return 'Error: Unknown instance name given' if object.nil?
        end
        if block_given?
            yield get_pool_element(object, id, client)
        else
            return get_pool_element(object, id, client)
        end
    end

    def ChooseDS(ds_type)
        dss = DatastoresMonitoring('sys').sort! { | ds | 100 * ds['used'].to_f / ds['full_size'].to_f }
        dss.delete_if { |ds| ds['type'] != ds_type || ds['deploy'] != 'TRUE' }
        ds = dss[rand(dss.size)]
        LOG "Deploying to #{ds['name']}", 'DEBUG'
        return ds['id']
    end
end

class User
    # Sets user quota by his existing VMs and/or appends new vm specs to it
    # @param [Hash] spec
    # @option spec [Boolean]          'append'  Set it true if you wish to append specs
    # @option spec [Integer | String] 'cpu'     CPU quota limit to append
    # @option spec [Integer | String] 'ram'     RAM quota limit to append
    # @note Method sets quota to 'used' values by default
    # @return nil
    def update_quota_by_vm(spec = {})
        quota = (self.info! || self.to_hash)['USER']['VM_QUOTA']['VM']
        if quota.nil? then
            quota = Hash.new
        end
        self.set_quota(
            "VM=[
                CPU=\"#{(spec['cpu'].to_i + quota['CPU_USED'].to_i).to_s}\", 
                MEMORY=\"#{(spec['ram'].to_i + quota['MEMORY_USED'].to_i).to_s}\", 
                SYSTEM_DISK_SIZE=\"#{spec['drive'].to_i + quota['SYSTEM_DISK_SIZE_USED'].to_i}\", 
                VMS=\"#{spec['append'].nil? ? quota['VMS_USED'].to_s : (quota['VMS_USED'].to_i + 1).to_s}\" ]"
        )
    end
end

class VirtualMachine
    # Sets resources allocation limits at vCenter node
    # @note For correct work of this method, you must keep actual vCenter Password at VCENTER_PASSWORD_ACTUAL attribute in OpenNebula
    # @note Attention!!! VM will be rebooted at the process
    # @note Valid units are: CPU - MHz, RAM - MB
    # @note Method searches VM by it's default name: one-(id)-(name), if target vm got another name, you should provide it
    # @param [Hash] spec - List of limits should be applied to target VM
    # @option spec [Integer] :cpu  MHz limit for VMs CPU usage
    # @option spec [Integer] :ram  MBytes limit for VMs RAM space usage
    # @option spec [Integer] :iops IOPS limit for VMs disk
    # @option spec [String]  :name VM name on vCenter node
    # @return [String]
    # @example Return messages decode
    #   vm.setResourcesAllocationLimits(spec)
    #       => 'Reconfigure Success' -- Task finished with success code, all specs are equal to given
    #       => 'Reconfigure Unsuccessed' -- Some of specs didn't changed
    #       => 'Reconfigure Error:{error message}' -- Exception has been generated while proceed, check your configuration
    def setResourcesAllocationLimits(spec)
        LOG spec.debug_out, 'DEBUG'
        return 'Unsupported query' if IONe.new($class).get_vm_data(self.id)['IMPORTED'] == 'YES'        
        begin
            query, host = {}, onblock(Host, IONe.new($class).get_vm_host(self.id))
            host = host.info! || host.to_hash['HOST']['TEMPLATE']
            datacenter = VIM.connect(
                :host => host['VCENTER_HOST'], :insecure => true,
                :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
            ).serviceInstance.find_datacenter
            vm = recursive_find_vm(datacenter.vmFolder, spec[:name].nil? ? "one-#{self.info! || self.id}-#{self.name}" : spec[:name]).first
            disk = vm.disks.first

            query[:cpuAllocation] = {:limit => spec[:cpu], :reservation => spec[:cpu]} if !spec[:cpu].nil?
            query[:memoryAllocation] = {:limit => spec[:ram]} if !spec[:ram].nil?
            if !spec[:iops].nil? then
                disk.storageIOAllocation.limit = spec[:iops]
                disk.backing.sharing = nil
                query[:deviceChange] = [{
                        :device => disk,
                        :operation => :edit
                }]
            end

            LOG 'Powering VM Off', 'DEBUG'
            LOG vm.PowerOffVM_Task.wait_for_completion, 'DEBUG'
            LOG 'Reconfiguring VM', 'DEBUG'
            LOG vm.ReconfigVM_Task(:spec => query).wait_for_completion, 'DEBUG'
            LOG 'Powering VM On', 'DEBUG'
            LOG vm.PowerOnVM_Task.wait_for_completion, 'DEBUG'

        rescue => e
            return "Reconfigure Error:#{e.message}"
        end
        return nil
    end
    # Gets resources allocation limits from vCenter node
    # @param [String] name VM name on vCenter node
    # @note For correct work of this method, you must keep actual vCenter Password at VCENTER_PASSWORD_ACTUAL attribute in OpenNebula
    # @note Method searches VM by it's default name: one-(id)-(name), if target vm got another name, you should provide it
    # @return [Hash | String] Returns limits Hash if success or exception message if fails
    def getResourcesAllocationLimits(name = nil)
        begin
            host = onblock(Host, IONe.new($class).get_vm_host(self.id))
            host = host.info! || host.to_hash['HOST']['TEMPLATE']
            datacenter = VIM.connect(
                :host => host['VCENTER_HOST'], :insecure => true,
                :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
            ).serviceInstance.find_datacenter
            vm = recursive_find_vm(datacenter.vmFolder, name.nil? ? "one-#{self.info! || self.id}-#{self.name}" : name).first
            vm_disk = vm.disks.first
            return {cpu: vm.config.cpuAllocation.limit, ram: vm.config.cpuAllocation.limit, iops: vm_disk.storageIOAllocation.limit}
        rescue => e
            return "Unexpected error, cannot handle it: #{e.message}"
        end
    end
    # Returns owner user ID
    # @param [Boolean] info method doesn't get object full info one more time -- usefull if collecting data from pool
    # @return [Integer]
    def uid(info = true)
        self.info! if info
        return self.to_hash['VM']['UID'].to_i
    end
    # Gives info about snapshots availability
    # @return [Boolean]
    def got_snapshot?
        self.info!
        return !self.to_hash['VM']['TEMPLATE']['SNAPSHOT'].nil?
    end
    # Returns all available snapshots
    # @return [Array<Hash>, Hash, nil]
    def list_snapshots
        out = self.info! || self.to_hash['VM']['TEMPLATE']['SNAPSHOT']
        return out.class == Array ? out : [ out ]
    end
end