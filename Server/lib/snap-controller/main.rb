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
    LOG 'Snapshot Controller has been initialized', 'SnapController'
    while true do
        begin
            vm_pool = VirtualMachinePool.new($client)
            vm_pool.info_all
            target_vms, out, iter, found = [], "", -1, true
            while found do
                iter += 1
                found = false
                vm_pool.each do | vm |
                    target_vms << vm if vm.got_snapshot?
                end
                target_vms.each do | vm |
                    active_state = WHMHandler.new($client).STATE(vm.id) * WHMHandler.new($client).LCM_STATE(vm.id) == 9
                    if vm.list_snapshots.class == Array then
                        vm.list_snapshots.each do | snap |
                            break if snap.class == Array
                            age = ((Time.now.to_i - snap['TIME'].to_i) / 3600.0).round(1)
                            out += "\t\t\t\t|  #{age >= 24 ? 'V' : 'X'}  |  #{active_state && age >= 24 ? 'V' : 'X'}  |  #{vm.id} |   #{' ' if age < 10}#{age}  | #{snap['NAME']}\n"
                            WHMHandler.new($client).RMSnapshot(vm.id, snap['SNAPSHOT_ID'], false)  || found = true if age >= 24 && active_state
                        end
                    else
                        snap = vm.list_snapshots
                        age = ((Time.now.to_i - snap['TIME'].to_i) / 3600.0).round(1)
                        out += "\t\t\t\t|  #{age >= 24 ? 'V' : 'X'}  |  #{active_state && age >= 24 ? 'V' : 'X'}  |  #{vm.id} |   #{' ' if age < 10}#{age}  | #{snap['NAME']}\n"
                        WHMHandler.new($client).RMSnapshot(vm.id, snap['SNAPSHOT_ID'], false)  || found = true if age >= 24 && active_state
                    end
                end
                sleep(300) if found
            end
            LOG "Detected snapshots:\n\t\t\t\t| rm? | del | vmid |   age   |          name          \n#{out}\nDeleting snapshots, which marked with 'V'", 'SnapController'
            sleep(3600 - iter * 300)
        rescue => e
            LOG "SnapController Error, code: #{e.message}\nSnapController is down now", 'SnapController'
        end
    end
end

class WHMHandler
    def GetSnapshotList(vmid)
        return get_pool_element(VirtualMachine, vmid, $client).list_snapshots
    end
end