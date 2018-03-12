require 'rbvmomi'
VIM = RbVmomi::VIM


def get_pool_element(type, id, client)
    return type.new(type.build_xml(id), client)
end

def onblock(object, id, client = 'none')
    client = $client if client == 'none'
    case object
        when 'vm'
            object = VirtualMachine
        when 'temp'
            object = Template
        when 'host'
            object = Host
        when 'user'
            object = User
        else
            return 'Error: Unknown class entered' if object.class != Class
    end
    if block_given?
        yield get_pool_element(object, id, client)
    else
        return get_pool_element(object, id, client)
    end
end

class User
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
    # Обязательно хранить актуальный пароль от vCenter атрибутом VCENTER_PASSWORD_ACTUAL
    # Attention!!! VM will be rebooted
    # CPU - MHz, RAM - MB
    def setResourcesAllocationLimits(spec)
        LOG spec.debug_out, 'DEBUG'
        begin
            query, host = {}, onblock(Host, IONe.new($class).get_vm_host(self.id))
            host = host.info! || host.to_hash['HOST']['TEMPLATE']
            datacenter = VIM.connect(
                :host => host['VCENTER_HOST'], :insecure => true,
                :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
            ).serviceInstance.find_datacenter
            vm = datacenter.find_vm("one-#{self.info! || self.id}-#{self.name}")
            disk = vm.disks.first

            query[:cpuAllocation] = {:limit => spec[:cpu]} if !spec[:cpu].nil?
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

            spec_new = self.getResourcesAllocationLimits
            result = spec[:cpu] == spec_new[:cpu] && spec[:ram] == spec_new[:ram] && spec[:iops] == spec_new[:iops]

            return 'Reconfigure Unsuccessed' if result

        rescue => e
            return 'Reconfigure Error'
        end
        return 'Reconfigure Success'
    end
    def getResourcesAllocationLimits
        return 'Unsupported query' if IONe.new($class).get_vm_data(self.id)['IMPORTED'] == 'YES'
        begin
            host = onblock(Host, IONe.new($class).get_vm_host(self.id))
            host = host.info! || host.to_hash['HOST']['TEMPLATE']
            datacenter = VIM.connect(
                :host => host['VCENTER_HOST'], :insecure => true,
                :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
            ).serviceInstance.find_datacenter
            vm = datacenter.find_vm("one-#{self.info! || self.id}-#{self.name}")
            vm_disk = vm.disks.first
            return {cpu: vm.config.cpuAllocation.limit, ram: vm.config.cpuAllocation.limit, iops: vm_disk.storageIOAllocation.limit}
        rescue => e
            return 'Unexpected error, cannot handle it', e
        end
    end
    def uid(info = true)
        self.info! if info
        return self.to_hash['VM']['UID'].to_i
    end
    def got_snapshot?
        self.info!
        return !self.to_hash['VM']['TEMPLATE']['SNAPSHOT'].nil?
    end
    def list_snapshots
        out = self.info! || self.to_hash['VM']['TEMPLATE']['SNAPSHOT']
        return out.class == Array ? out : [ out ]
    end
end