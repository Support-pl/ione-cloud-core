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
    def setResourcesAllocationLimits(spec)
        query, host = {}, onblock(Host, get_vm_host(self.id))
        host = host.info! || host.to_hash['HOST']['TEMPLATE']
        datacenter = VIM.connect(
            :host => host['VCENTER_HOST'], :insecure => true,
            :user => host['VCENTER_USER'], :password => host['VCENTER_PASSWORD_ACTUAL']
        ).serviceInstance.find_datacenter
        vm = datacenter.find_vm("one-#{self.info! || self.id}-#{self.name}")
        vm_disk = vm.disks.first

        query[:cpuAllocation] = {:limit => spec[:cpu]} if !spec[:cpu].nil?
        query[:memoryAllocation] = {:limit => spec[:ram]} if !spec[:ram].nil?
        if !spec[:iops].nil? then
            disk.storageIOAllocation.limit = 300
            disk.backing.sharing = nil
            query[:deviceChange] = [{
                    :device => disk,
                    :operation => :edit
            }]
        end
    end
end