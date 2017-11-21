class VirtualMachine
    def got_snapshot?
        self.info!
        return !self.to_hash['VM']['TEMPLATE']['SNAPSHOT'].nil?
    end
    def list_snapshots
        self.info!
        return self.to_hash['VM']['TEMPLATE']['SNAPSHOT']
    end
end

Thread.new do 
    while true do
        vm_pool = VirtualMachinePool.new($client)
        vm_pool.info_all
        target_vms, out = [], ""
        vm_pool.each do | vm |
            target_vms << vm if vm.got_snapshot?
        end
        target_vms.each do | vm |
            vm.list_snapshots.each do | snap |
                break if snap.class == Array
                age = ((Time.now.to_i - snap['TIME'].to_i) / 3600.0).round(1)
                out += "\t\t\t\t|  #{age >= 24 ? 'V' : 'X'}  |  #{vm.id} |   #{' ' if age < 10}#{age}  | #{snap['NAME']}\n"
                WHMHandler.new($client).RMSnapshot(vm.id, snap['SNAPSHOT_ID']) if age >= 24
            end
        end
        LOG "Detected snapshots:\n\t\t\t\t| rm? | vmid |   age   |          name          \n#{out}\nDeleting snapshots, which marked with 'V'", 'SnapController'
        
        sleep(3600)
    end
end