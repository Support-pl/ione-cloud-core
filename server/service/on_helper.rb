require 'rbvmomi'

# Useful methods for OpenNebula classes, functions and constants.
module ONeHelper
    
    VIM = RbVmomi::VIM # Alias for RbVmomi::VIM

    # Searches Instances at vCenter by name at given folder
    # @param [RbVmomi::VIM::Folder] folder - folder where search
    # @param [String] name - VM name at vCenter
    # @param [Boolean] exact
    # @return [Array<RbVmomi::VIM::VirtualMachine>]
    # @note Tested and used for VMs, but can search at any datacenter folder
    # @note Source https://github.com/MarkArbogast/vsphere-helper/blob/master/lib/vsphere_helper/helpers.rb#L51-#L68
    def recursive_find_vm(folder, name, exact = false)
        # @!visibility private
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
    # Returns random Datastore ID filtered by disk type
    # @note Remember to configure DRIVE_TYPE(HDD|SSD) and DEPLOY(TRUE|FALSE) attributes at your Datastores
    # @param [String] ds_type   - Datastore type, may be HDD or SSD, returns any DS if not given
    # @return [Integer]
    def ChooseDS(ds_type = nil)
        dss = IONe.new($client).DatastoresMonitoring('sys').sort! { | ds | 100 * ds['used'].to_f / ds['full_size'].to_f }
        dss.delete_if { |ds| ds['type'] != ds_type || ds['deploy'] != 'TRUE' } if ds_type != nil
        ds = dss[rand(dss.size)]
        LOG "Deploying to #{ds['name']}", 'DEBUG'
        return ds['id']
    end
    # Returns given cluster hypervisor type
    # @param [Integer] hostid ID of the host to check
    # @return [String]
    # @example
    #       ClusterType(0) => 'vcenter'
    #       ClusterType(1) => 'kvm'
    def ClusterType(hostid)
        onblock(:h, hostid) do | host |
            host.info!
            return host.to_hash['HOST']['TEMPLATE']['HYPERVISOR']
        end
    end
end

# OpenNebula::User class
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

# OpenNebula::Template class
class Template
    # Checks given template OS type by User Input
    # @return [Boolean]
    def win?
        self.info!
        return self.to_hash['VMTEMPLATE']['TEMPLATE']['USER_INPUTS'].include? 'USERNAME'
    end
end

# OpenNebula::VirtualMachine class
class VirtualMachine
    # Actions supported by OpenNebula scheduler
    SCHEDULABLE_ACTIONS = %w(
        terminate
        terminate-hard
        hold
        release
        stop
        suspend
        resume
        reboot
        reboot-hard
        poweroff
        poweroff-hard
        undeploy
        undeploy-hard
        snapshot-create
    )
    def generate_schedule_str(id, action, time)
        return "\nSCHED_ACTION=[\n" + 
        "  ACTION=\"#{action}\",\n" + 
        "  ID=\"#{id}\",\n" + 
        "  TIME=\"#{time}\" ]"
    end
    # Returns allowed actions to schedule
    # @return [Array]
    def schedule_actions
        return SCHEDULABLE_ACTIONS
    end
    # Adds actions to OpenNebula internal scheduler, like --schedule in 'onevm' cli utility
    # @param [String] action - Action which should be scheduled
    # @param [Integer] time - Time when action schould be perfomed in secs
    # @param [String] periodic - Not working now
    # @return true
    def schedule(action, time, periodic = nil)
        return 'Unsupported action' if !SCHEDULABLE_ACTIONS.include? action
        self.info!
        begin
            ids = self.to_hash['VM']['USER_TEMPLATE']['SCHED_ACTION']
            if ids.class == Array then
                id = ids.last['ID'].to_i + 1
            elsif ids.class == Hash then
                id = ids['ID'].to_i + 1
            elsif ids.class == NilClass then
                id = ids.to_i
            else
                raise
            end
        rescue
            id = 0
        end

        # str_periodic = ''

        self.update(self.user_template_str << generate_schedule_str(id, action, time))
    end
    # Unschedules given action by ID
    # @note Not working, if action is already initialized
    def unschedule(id)
        self.info!
        schedule_data, object = self.to_hash['VM']['USER_TEMPLATE']['SCHED_ACTION'], nil

        if schedule_data.class == Array then
            schedule_data.map do | el |
                object = el if el['ID'] == id.to_s
            end
        elsif schedule_data.class == Hash then
            return 'none' if schedule_data['ID'] != id.to_s
            object = schedule_data
        else
            return 'none'
        end
        action, time = object['ACTION'], object['TIME']
        template = self.user_template_str
        template.slice!(generate_schedule_str(id, action, time))
        self.update(template)
    end
    # Lists actions scheduled in OpenNebula
    # @return [NilClass | Hash | Array]
    def scheduler
        self.info!
        return self.to_hash['VM']['USER_TEMPLATE']['SCHED_ACTION']
    end
    # Waits until VM will have the given state
    # @param [Integer] s - VM state to wait for
    # @param [Integer] lcms_s - VM LCM state to wait for
    # @return [Boolean]
    def wait_for_state(s = 3, lcm_s = 3)
        i = 0
        until state(vmid) == s && lcm_state(vmid) == lcm_s do
            return false if i >= 3600
            sleep(1)
            i += 1
            self.info!
        end
        return true
    end
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
        return 'Unsupported query' if IONe.new($client).get_vm_data(self.id)['IMPORTED'] == 'YES'        
        begin
            query, host = {}, onblock(Host, IONe.new($client).get_vm_host(self.id))
            host = host.info! || host.to_hash['HOST']['TEMPLATE']
            datacenter = VIM.connect(
                :host => host['VCENTER_HOST'], :insecure => true,
                :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
            ).serviceInstance.find_datacenter
            vm = recursive_find_vm(datacenter.vmFolder, spec[:name].nil? ? "one-#{self.info! || self.id}-#{self.name}" : spec[:name]).first
            disk = vm.disks.first

            query[:cpuAllocation] = {:limit => spec[:cpu].to_i, :reservation => 0} if !spec[:cpu].nil?
            query[:memoryAllocation] = {:limit => spec[:ram].to_i} if !spec[:ram].nil?
            if !spec[:iops].nil? then
                disk.storageIOAllocation.limit = spec[:iops].to_i
                disk.backing.sharing = nil
                query[:deviceChange] = [{
                        :device => disk,
                        :operation => :edit
                }]
            end

            state = true
            begin
                LOG 'Powering VM Off', 'DEBUG'
                LOG vm.PowerOffVM_Task.wait_for_completion, 'DEBUG'
            rescue => e
                state = false
            end
            
                LOG 'Reconfiguring VM', 'DEBUG'
                LOG vm.ReconfigVM_Task(:spec => query).wait_for_completion, 'DEBUG'
            
            begin
                LOG 'Powering VM On', 'DEBUG'
                LOG vm.PowerOnVM_Task.wait_for_completion, 'DEBUG'
            rescue
            end if state

        rescue => e
            return "Reconfigure Error:#{e.message}"
        end
        return nil
    end
    # Resize VM without powering off the VM
    # @param [Hash] spec
    # @option spec [Integer] :cpu CPU amount to set
    # @option spec [Integer] :ram RAM amount in MB to set
    # @option spec [String] :name VM name on vCenter node
    # @return [Boolean | String]
    # @note Method returns true if resize action ended correct, false if VM not support hot reconfiguring
    def hot_resize(spec = {:name => nil})
        return false if !self.hotAddEnabled?
        begin
            host = onblock(Host, IONe.new($client).get_vm_host(self.id))
            host = host.info! || host.to_hash['HOST']['TEMPLATE']
            datacenter = VIM.connect(
                :host => host['VCENTER_HOST'], :insecure => true,
                :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
            ).serviceInstance.find_datacenter
            vm = recursive_find_vm(datacenter.vmFolder, spec[:name].nil? ? "one-#{self.info! || self.id}-#{self.name}" : spec[:name]).first
            query = {
                :numCPUs => spec[:cpu],
                :memoryMB => spec[:ram]
            }
            vm.ReconfigVM_Task(:spec => query).wait_for_completion
            return true
        rescue => e
            return "Reconfigure Error:#{e.message}"            
        end
    end
    # Checks if resources hot add enabled
    # @param [String] name VM name on vCenter node
    # @note For correct work of this method, you must keep actual vCenter Password at VCENTER_PASSWORD_ACTUAL attribute in OpenNebula
    # @note Method searches VM by it's default name: one-(id)-(name), if target vm got another name, you should provide it
    # @return [Hash | String] Returns limits Hash if success or exception message if fails
    def hotAddEnabled?(name = nil)
        begin
            host = onblock(Host, IONe.new($client).get_vm_host(self.id))
            host = host.info! || host.to_hash['HOST']['TEMPLATE']
            datacenter = VIM.connect(
                :host => host['VCENTER_HOST'], :insecure => true,
                :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
            ).serviceInstance.find_datacenter
            vm = recursive_find_vm(datacenter.vmFolder, name.nil? ? "one-#{self.info! || self.id}-#{self.name}" : name).first
            return {
                :cpu => vm.config.cpuHotAddEnabled, :ram => vm.config.memoryHotAddEnabled
            }
        rescue => e
            return "Unexpected error, cannot handle it: #{e.message}"
        end
    end
    # Sets resources hot add settings
    # @param [Hash] spec
    # @option spec [Boolean] :cpu 
    # @option spec [Boolean] :ram
    # @option spec [String]  :name VM name on vCenter node
    # @return [true | String]
    def hotResourcesControlConf(spec = {:cpu => true, :ram => true, :name => nil})
        begin
            host, name = onblock(Host, IONe.new($client).get_vm_host(self.id)), spec[:name]
            host = host.info! || host.to_hash['HOST']['TEMPLATE']
            datacenter = VIM.connect(
                :host => host['VCENTER_HOST'], :insecure => true,
                :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
            ).serviceInstance.find_datacenter
            vm = recursive_find_vm(datacenter.vmFolder, name.nil? ? "one-#{self.info! || self.id}-#{self.name}" : name).first
            query = {
                :cpuHotAddEnabled => spec[:cpu],
                :memoryHotAddEnabled => spec[:ram]
            }
            state = true
            begin
                LOG 'Powering VM Off', 'DEBUG'
                LOG vm.PowerOffVM_Task.wait_for_completion, 'DEBUG'
            rescue => e
                state = false
            end
            
                LOG 'Reconfiguring VM', 'DEBUG'
                LOG vm.ReconfigVM_Task(:spec => query).wait_for_completion, 'DEBUG'
            
            begin
                LOG 'Powering VM On', 'DEBUG'
                LOG vm.PowerOnVM_Task.wait_for_completion, 'DEBUG'
            rescue
            end if state
        rescue => e
            return "Unexpected error, cannot handle it: #{e.message}"
        end
    end
    # Gets resources allocation limits from vCenter node
    # @param [String] name VM name on vCenter node
    # @note For correct work of this method, you must keep actual vCenter Password at VCENTER_PASSWORD_ACTUAL attribute in OpenNebula
    # @note Method searches VM by it's default name: one-(id)-(name), if target vm got another name, you should provide it
    # @return [Hash | String] Returns limits Hash if success or exception message if fails
    def getResourcesAllocationLimits(name = nil)
        begin
            host = onblock(Host, IONe.new($client).get_vm_host(self.id))
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