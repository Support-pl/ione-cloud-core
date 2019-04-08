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
        # Comparator for object names
        def matches(child, name, exact = false)
            is_vm = child.class == RbVmomi::VIM::VirtualMachine
            name_matches = (name == "*") || (exact ? (child.name == name) : (child.name.include? name))
            is_vm && name_matches
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
    # Searches Instances at vCenter by name at given folder
    # @param [RbVmomi::VIM::Folder] folder - folder where search
    # @param [String] name - DS name at vCenter
    # @param [Boolean] exact
    # @return [Array<RbVmomi::VIM::Datastore>]
    def recursive_find_ds(folder, name, exact = false)
        # @!visibility private
        # Comparator for object names
        def matches(child, name, exact = false)
            is_ds = child.class == RbVmomi::VIM::Datastore
            name_matches = (name == "*") || (exact ? (child.name == name) : (child.name.include? name))
            is_ds && name_matches
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

    # Returns VIM::Datacenter for host
    # @param [OpenNebula::Host] host
    # @return [Datacenter]
    def get_vcenter_dc(host)
        host = host.to_hash!['HOST']['TEMPLATE']
        VIM.connect(
            :host => host['VCENTER_HOST'], :insecure => true,
            :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
        ).serviceInstance.find_datacenter
    end
    # Returns Datastore IP and Path
    # @param [Integer] host - host ID
    # @param [String] name - Datastore name
    # @return [String, String] ip, path
    def get_ds_vdata(host, name)
        get_vcenter_dc(onblock(:h, host)).datastoreFolder.children.each do | ds |
            next if ds.name != name
            begin
                return ds.info.nas.remoteHost, ds.info.nas.remotePath
            rescue => e
                return nil
            end
        end
        nil
    end

    # Prints given objects classes
    # @param [Array] args
    # @return [NilClass]
    def putc(*args)
        args.each do | el |
            puts el.class
        end
        nil
    end

    # {#onblock} supported instances list 
    ON_INSTANCES = {
        :vm  => VirtualMachine,
        :t   => Template,
        :h   => Host,
        :u   => User,
        :vn  => VirtualNetwork,
        :ds  => Datastore,
        :mpa => MarketPlaceApp,
        :ma  => MarketPlace,
        :vr  => VirtualRouter,
        :vdc => Vdc,
        :sg  => SecurityGroup,
        :z   => Zone,
        :d   => Document,
        :c   => Cluster,
        :acl => Acl,
        :g   => Group,
        :i   => Image,
        :p   => Pool
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
        type.new(type.build_xml(id), client)
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
            yield get_pool_element(object, id.to_i, client)
        else
            get_pool_element(object, id.to_i, client)
        end
    end
    # Returns random Datastore ID filtered by disk type
    # @note Remember to configure DRIVE_TYPE(HDD|SSD) and DEPLOY(TRUE|FALSE) attributes at your Datastores
    # @param [String] ds_type   - Datastore type, may be HDD or SSD, returns any DS if not given
    # @return [Integer]
    def ChooseDS(ds_type = nil)
        dss = IONe.new($client, $db).DatastoresMonitoring('sys').sort! { | ds | 100 * ds['used'].to_f / ds['full_size'].to_f }
        dss.delete_if { |ds| ds['type'] != ds_type || ds['deploy'] != 'TRUE' } if ds_type != nil
        ds = dss[rand(dss.size)]
        LOG_DEBUG "Deploying to #{ds['name']}"
        ds['id']
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
            host.to_hash['HOST']['TEMPLATE']['HYPERVISOR']
        end
    end
end

# OpenNebula::User class
class OpenNebula::User
    # Sets user quota by his existing VMs and/or appends new vm specs to it
    # @param [Hash] spec
    # @option spec [Boolean]          'append'  Set it true if you wish to append specs
    # @option spec [Integer | String] 'cpu'     CPU quota limit to append
    # @option spec [Integer | String] 'ram'     RAM quota limit to append
    # @note Method sets quota to 'used' values by default
    # @return nil
    def update_quota_by_vm(spec = {})
        quota = self.to_hash!['USER']['VM_QUOTA']['VM']
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
    def name!
        info!
        name
    end

    def balance
        to_hash!['USER']['TEMPLATE']['BALANCE']
    end
    def balance= num
        update("BALANCE = #{num}", true)
    end
    def alert
        alert_at = to_hash!['USER']['TEMPLATE']['ALERT'] || $db[:settings].where(:name => 'ALERT').to_a.last[:body]
        return balance <= alert_at, alert_at
    end
    def alert= at
        update("ALERT = #{at}", true)
    end
    def vms
        vm_pool = VirtualMachinePool.new(@client, id)
        vm_pool.info!
        vm_pool.to_a
    rescue
        nil
    end
    def exists?
        self.info! == nil
    end

    class UserNotExistsError < StandardError
        def initialize msg = "User not exists or error occurred while getting user."
           super
        end
    end
end

# OpenNebula::Template class
class OpenNebula::Template
    # Checks given template OS type by User Input
    # @return [Boolean]
    def win?
        self.info!
        self.to_hash['VMTEMPLATE']['TEMPLATE']['USER_INPUTS'].include? 'USERNAME'
    end
end

# OpenNebula::VirtualMachine class
class OpenNebula::VirtualMachine
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
    # Generates template for OpenNebula scheduler record
    def generate_schedule_str(id, action, time)
        "\nSCHED_ACTION=[\n" + 
        "  ACTION=\"#{action}\",\n" + 
        "  ID=\"#{id}\",\n" + 
        "  TIME=\"#{time}\" ]"
    end
    # Returns allowed actions to schedule
    # @return [Array]
    def schedule_actions
        SCHEDULABLE_ACTIONS
    end
    # Adds actions to OpenNebula internal scheduler, like --schedule in 'onevm' cli utility
    # @param [String] action - Action which should be scheduled
    # @param [Integer] time - Time when action schould be perfomed in secs
    # @param [String] periodic - Not working now
    # @return true
    def schedule(action, time, periodic = nil)
        return 'Unsupported action' if !SCHEDULABLE_ACTIONS.include? action
        self.info!
        id = 
            begin
                ids = self.to_hash['VM']['USER_TEMPLATE']['SCHED_ACTION']
                if ids.class == Array then
                    ids.last['ID'].to_i + 1
                elsif ids.class == Hash then
                    ids['ID'].to_i + 1
                elsif ids.class == NilClass then
                    ids.to_i
                else
                    raise
                end
            rescue
                0
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
        self.to_hash['VM']['USER_TEMPLATE']['SCHED_ACTION']
    end
    # Waits until VM will have the given state
    # @param [Integer] s - VM state to wait for
    # @param [Integer] lcm_s - VM LCM state to wait for
    # @return [Boolean]
    def wait_for_state(s = 3, lcm_s = 3)
        i = 0
        until state() == s && lcm_state() == lcm_s do
            return false if i >= 3600
            sleep(1)
            i += 1
            self.info!
        end
        true
    end

    #!@group vCenterHelper

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
        LOG_DEBUG spec.debug_out
        return 'Unsupported query' if IONe.new($client, $db).get_vm_data(self.id)['IMPORTED'] == 'YES'        
        
        query, host = {}, onblock(Host, IONe.new($client, $db).get_vm_host(self.id))
        datacenter = get_vcenter_dc(host)

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
            LOG_DEBUG 'Powering VM Off'
            LOG_DEBUG vm.PowerOffVM_Task.wait_for_completion
        rescue => e
            state = false
        end
        
            LOG_DEBUG 'Reconfiguring VM'
            LOG_DEBUG vm.ReconfigVM_Task(:spec => query).wait_for_completion
        
        begin
            LOG_DEBUG 'Powering VM On'
            LOG_DEBUG vm.PowerOnVM_Task.wait_for_completion
        rescue
        end if state

    rescue => e
        return "Reconfigure Error:#{e.message}<|>Backtrace:#{e.backtrace}"
    ensure
        return nil
    end
    # Checks if vm is on given vCenter Datastore
    def is_at_ds?(ds_name)
        query, host = {}, onblock(Host, IONe.new($client, $db).get_vm_host(self.id))
        datacenter = get_vcenter_dc(host)
        begin
            datastore = recursive_find_ds(datacenter.datastoreFolder, ds_name, true).first
        rescue => e
            return 'Invalid DS name.'
        end
        self.info!
        search_template = "VirtualMachine(\"#{self.deploy_id}\")"
        datastore.vm.each do | vm |
            return true if vm.to_s == search_template
        end
        false
    end
    # Gets the datastore, where VM allocated is
    # @return [String] DS name
    def get_vms_vcenter_ds
        query, host = {}, onblock(Host, IONe.new($client, $db).get_vm_host(self.id))
        datastores = get_vcenter_dc(host).datastoreFolder.children
        
        self.info!
        search_template = "VirtualMachine(\"#{self.deploy_id}\")"
        datastores.each do | ds |
            ds.vm.each do | vm |
                return ds.name if vm.to_s == search_template
            end
        end
    end
    # Resizes VM without powering off the VM
    # @param [Hash] spec
    # @option spec [Integer] :cpu CPU amount to set
    # @option spec [Integer] :ram RAM amount in MB to set
    # @option spec [String] :name VM name on vCenter node
    # @return [Boolean | String]
    # @note Method returns true if resize action ended correct, false if VM not support hot reconfiguring
    def hot_resize(spec = {:name => nil})
        return false if !self.hotAddEnabled?
        begin
            host = onblock(Host, IONe.new($client, $db).get_vm_host(self.id))
            datacenter = get_vcenter_dc(host)

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
            host = onblock(:h, IONe.new($client, $db).get_vm_host(self.id))
            datacenter = get_vcenter_dc(host)

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
            host, name = onblock(Host, IONe.new($client, $db).get_vm_host(self.id)), spec[:name]
            datacenter = get_vcenter_dc(host)

            vm = recursive_find_vm(datacenter.vmFolder, name.nil? ? "one-#{self.info! || self.id}-#{self.name}" : name).first
            query = {
                :cpuHotAddEnabled => spec[:cpu],
                :memoryHotAddEnabled => spec[:ram]
            }
            state = true
            begin
                LOG_DEBUG 'Powering VM Off'
                LOG_DEBUG vm.PowerOffVM_Task.wait_for_completion
            rescue => e
                state = false
            end
            
                LOG_DEBUG 'Reconfiguring VM'
                LOG_DEBUG vm.ReconfigVM_Task(:spec => query).wait_for_completion
            
            begin
                LOG_DEBUG 'Powering VM On'
                LOG_DEBUG vm.PowerOnVM_Task.wait_for_completion
            rescue
            end if state
        rescue => e
            "Unexpected error, cannot handle it: #{e.message}"
        end
    end
    # Gets resources allocation limits from vCenter node
    # @param [String] name VM name on vCenter node
    # @note For correct work of this method, you must keep actual vCenter Password at VCENTER_PASSWORD_ACTUAL attribute in OpenNebula
    # @note Method searches VM by it's default name: one-(id)-(name), if target vm got another name, you should provide it
    # @return [Hash | String] Returns limits Hash if success or exception message if fails
    def getResourcesAllocationLimits(name = nil)
        begin
            host = onblock(Host, IONe.new($client, $db).get_vm_host(self.id))
            datacenter = get_vcenter_dc(host)

            vm = recursive_find_vm(datacenter.vmFolder, name.nil? ? "one-#{self.info! || self.id}-#{self.name}" : name).first
            vm_disk = vm.disks.first
            {cpu: vm.config.cpuAllocation.limit, ram: vm.config.cpuAllocation.limit, iops: vm_disk.storageIOAllocation.limit}
        rescue => e
            "Unexpected error, cannot handle it: #{e.message}"
        end
    end

    #!@endgroup

    # Returns owner user ID
    # @param [Boolean] info method doesn't get object full info one more time -- usefull if collecting data from pool
    # @return [Integer]
    def uid(info = true, from_pool = false)
        self.info! if info
        return @xml[0].children[1].text.to_i unless from_pool
        @xml.children[1].text.to_i
    end
    def uname(info = true, from_pool = false)
        self.info! if info
        return @xml[0].children[3].text.to_i unless from_pool
        @xml.children[3].text
    end
    # Gives info about snapshots availability
    # @return [Boolean]
    def got_snapshot?
        self.info!
        !self.to_hash['VM']['TEMPLATE']['SNAPSHOT'].nil?
    end
    # Returns all available snapshots
    # @return [Array<Hash>, Hash, nil]
    def list_snapshots
        out = self.to_hash!['VM']['TEMPLATE']['SNAPSHOT']
        out.class == Array ? out : [ out ]
    end
    # Returns actual state without calling info! method
    def state!
        self.info! || self.state
    end
    # Returns actual lcm state without calling info! method
    def lcm_state!
        self.info! || self.lcm_state
    end
    # Returns actual state as string without calling info! method
    def state_str!
        self.info! || self.state_str
    end
    # Returns actual lcm state as string without calling info! method
    def lcm_state_str!
        self.info! || self.lcm_state_str
    end

    def calculate_showback stime_req, etime_req
        raise ShowbackError, ["Wrong Time-period given", stime_req, etime_req] if stime_req >= etime_req
        
        info!

        stime, etime = stime_req, etime_req

        stime = self['/VM/STIME'].to_i if self['/VM/STIME'].to_i > stime
        etime = self['/VM/ETIME'].to_i if self['/VM/ETIME'].to_i > etime

        requested_time = (etime - stime) / 3600.0

        def action_type action
            result = 
                case action.to_i
                when 1, 2, 5, 6, 9, 10, 19, 20
                    false
                else
                    true
                end
            return result
        end

        history_records = to_hash['VM']['HISTORY_RECORDS']['HISTORY']
        if history_records.nil? && state == 6 then
            hr = History.new(id, @client)
            return {
                "work_time" => 0,
                "time_period_requested" => etime_req - stime_req,
                "time_period_corrected" => etime - stime,
                "CPU" => 0,
                "MEMORY" => 0,
                "DISK" => 0,
                "DISK_TYPE" => 'no_type',
                "PUBLIC_IP" => 0,
                "EXCEPTION" => "No Records",
                "TOTAL" => 0
            } if hr.info!.class == OpenNebula::History::NoRecordsError
            history_records = hr.records.map {|record| record['HISTORY'].without('VM')}
        end
        history_records = history_records.class == Array ? history_records : [ history_records ]

        timeline = []
        history_records.each do | record |
            timeline << {
                'stime' => record['STIME'].to_i,
                'etime' => record['ETIME'].to_i,
                'state' => action_type(record['ACTION'])
            }
        end

        index = 0
        while index < timeline.length - 1 do
            if timeline[index]['state'] == timeline[index + 1]['state'] then
                timeline.insert(
                    index + 1,
                    {
                        'stime' => timeline[index]['stime'] + 1,
                        'etime' => timeline[index + 1]['stime'] - 1,
                        'state' => !timeline[index]['state']
                    }
                )
                index += 2
            else
                break
            end
        end

        timeline[timeline.length - 1]['etime'] = etime if timeline.last['etime'] == 0
        
        work_time = 0
        timeline.each do | record |
            next unless record['state']
            next if stime > record['etime']
            work_time += (record['etime'] - record['stime'])
            work_time -= (record['stime'] < stime && stime < record['etime'] ? stime - record['stime'] : 0)
            work_time -= (record['etime'] > etime && etime > record['stime'] ? record['etime'] - etime : 0)
        end
        work_time = work_time / 3600.0

        cpu, memory = self['/VM/TEMPLATE/CPU'].to_f, self['/VM/TEMPLATE/MEMORY'].to_f / 1024
        disk = self['/VM/TEMPLATE/DISK/SIZE'].to_f / 1024
        
        public_ip = 0
        nic = to_hash['VM']['TEMPLATE']['NIC']
        if nic.class == Array then
            nic.each do | el |
                vnet = VirtualNetwork.new_with_id el['NETWORK_ID'], @client
                vnet.info!
                public_ip += vnet['/VNET/TEMPLATE/TYPE'] == 'PUBLIC' ? 1 : 0
            end
        elsif nic.class == Hash 
            vnet = VirtualNetwork.new_with_id nic['NETWORK_ID'], @client
            vnet.info!
            public_ip += vnet['/VNET/TEMPLATE/TYPE'] == 'PUBLIC' ? 1 : 0
        end

        cpu_cost = cpu * work_time * self['/VM/TEMPLATE/CPU_COST'].to_f
        memory_cost = memory * work_time * self['/VM/TEMPLATE/MEMORY_COST'].to_f
        disk_cost = disk * requested_time * self['/VM/TEMPLATE/DISK_COST'].to_f
        public_ip_cost = public_ip * requested_time * self['/VM/USER_TEMPLATE/PUBLIC_IP_COST'].to_f
        
        return {
            "work_time" => work_time,
            "time_period_requested" => etime_req - stime_req,
            "time_period_corrected" => etime - stime,
            "CPU" => cpu_cost,
            "MEMORY" => memory_cost,
            "DISK" => disk_cost,
            "DISK_TYPE" => self['/VM/USER_TEMPLATE/DRIVE'],
            "PUBLIC_IP" => public_ip_cost,
            "TOTAL" => cpu_cost + memory_cost + disk_cost + public_ip_cost
        }
    end

    class ShowbackError < StandardError

        attr_reader :params

        def initialize params = []
            @params = params[1..(params.length - 1)]
            super "#{params[0]}\nParams:#{@params.inspect}"
        end
    end
end

# OpenNebula::XMLElement class
class OpenNebula::XMLElement
    # Calls info! method and returns a hash representing the object
    def to_hash!
        self.info! || self.to_hash
    end
end

class OpenNebula::History
    require 'nori'

    attr_reader :id, :records

    def initialize id, client
        @client = client
        @id = id
        @parser = Nori.new
    end
    def info
        rc = System.new(@client).sql_query_command("SELECT body FROM history WHERE vid=#{@id}")
        rc = @parser.parse rc
        records = rc['SQL_COMMAND']['RESULT']['ROW']
        records.map! {|record| @parser.parse(Base64.decode64(record['body64'])) }

        @records = records
    rescue
        NoRecordsError.new "Error occurred while parsing"
    end
    alias_method :info!, :info

    class NoRecordsError < StandardError; end
end