########################################################
#        Методы для управления ВМ и Аккаунтами         #
########################################################

puts 'Extending Handler class by commerce-useful methods'
class IONe
    # Suspends VirtualMachine and makes it uncontrollable for Owner(except Admins)
    # @param [Hash] params - income data
    # @option params [Integer] :vmid VirtualMachine ID for blocking
    # @param [Boolean] log - logs process if true
    # @param [Array<String>] trace
    # @return [nil | Array] Returns message and trace if Exception
    def Suspend(params, log = true, trace = ["Suspend method called:#{__LINE__}"])
        begin
            LOG_STAT()
            LOG "Suspending VM#{params['vmid']}", "Suspend" if log
            LOG "Params: #{params.inspect} | log = #{log}", "Suspend" if log
            trace << "Creating VM object:#{__LINE__ + 1}"
            onblock(VirtualMachine, params['vmid'].to_i) do | vm |
                trace << "Suspending VM:#{__LINE__ + 1}"
                vm.suspend
                trace << "Changing user rights:#{__LINE__ + 1}"
                vm.chmod(
                    -1,  0, -1,
                    -1, -1, -1,
                    -1, -1, -1
                    )
            end
            trace << "Killing proccess:#{__LINE__ + 1}"
            return 0
        rescue => e
            return e.message, trace
        end
    end
    # Suspends VirtualMachine only
    # @param [Integer] vmid - VirtualMachine ID
    # @return [nil]
    def SuspendVM(vmid)
        onblock(VirtualMachine, vmid.to_i).suspend
    end
    # Unsuspends VirtualMachine and makes it uncontrollable for Owner(except Admins)
    # @note May be used as PowerON method like {#Resume}
    # @param [Hash] params - income data
    # @option params [Integer] :vmid VirtualMachine ID for blocking
    # @param [Array<String>] trace
    # @return [nil | Array] Returns message and trace if Exception
    def Unsuspend(params, trace = ["Resume method called:#{__LINE__}"])
        begin
            LOG_STAT()
            LOG "Resuming VM ##{params['vmid']}", "Resume"
            trace << "Creating VM object:#{__LINE__ + 1}"            
            onblock(VirtualMachine, params['vmid'].to_i) do | vm |
                trace << "Resuming VM:#{__LINE__ + 1}"                
                vm.resume
                trace << "Changing user rights:#{__LINE__ + 1}"                
                vm.chmod(
                    -1,  1, -1,
                    -1, -1, -1,
                    -1, -1, -1
                )
            end
            trace << "Killing proccess:#{__LINE__ + 1}"            
            return 0
        rescue => e
            return e.message, trace
        end
    end
    # Reboots Virtual Machine
    # @param [Integer] vmid - VirtualMachine ID to reboot
    # @param [Boolean] hard - uses reboot-hard if true
    # @return nil
    def Reboot(vmid, hard = false)
        LOG_STAT()
                  
        return "VMID cannot be nil!" if vmid.nil?     
        LOG "Rebooting VM#{vmid}", "Reboot"
        LOG "Params: vmid = #{vmid}, hard = #{hard}", "DEBUG" #if DEBUG
        return onblock(VirtualMachine, vmid.to_i).reboot(hard) # true означает, что будет вызвана функция reboot-hard
    end
    # Terminates(deletes) user account and VM
    # @param [Integer] userid - user to delete
    # @param [Integer] vmid - VM to delete
    # @return [nil | OpenNebula::Error]    
    def Terminate(userid, vmid)
        LOG_STAT()
                  
        begin
            LOG "Terminate query call params: {\"userid\" => #{userid}, \"vmid\" => #{vmid}}", "Terminate"
            # If userid will be nil oneadmin account can be broken
            if userid == nil || vmid == nil then
                LOG "Terminate query rejected! 1 of 2 params is nilClass!", "Terminate"
                return 1
            elsif userid == 0 then
                LOG "Terminate query rejected! Tryed to delete root-user(oneadmin)", "Terminate"
            end
            Delete(userid)
            LOG "Terminating VM#{vmid}", "Terminate"
            onblock(VirtualMachine, vmid).recover 3 # recover с параметром 3 означает полное удаление с диска
        rescue => err
            return err
        end
        return 0
    end
    # Powering off VM
    # @note Don't user OpenNebula::VirtualMachine#shutdown - this method deletes VM's
    # @param [Integer] vmid - VM to shutdown
    # @return [nil | OpenNebula::Error]
    def Shutdown(vmid)
        LOG_STAT()
                
        LOG "Shutting down VM#{vmid}", "Shutdown"
        return onblock(VirtualMachine, vmid).poweroff
    end
    # @!visibility private
    def Release(vmid)
        LOG_STAT()
        LOG "New Release Order Accepted!", "Release"
        onblock(VirtualMachine, vmid).release
    end
    # Deletes given user by ID
    # @param [Integer] userid
    # @return [nil | OpenNebula::Error]
    def Delete(userid)
        LOG_STAT()
        if userid == 0 then
            LOG "Delete query rejected! Tryed to delete root-user(oneadmin)", "Delete"
        end
        LOG "Deleting User ##{userid}", "Delete"
        onblock(User, userid).delete
    end
    # Powers On given VM if powered off, or unsuspends if suspended by ID
    # @param [Integer] vmid
    # @return [nil | OpenNebula::Error]
    def Resume(vmid)
        LOG_STAT()
        return onblock(VirtualMachine, vmid.to_i).resume
    end
    # Removes choosen snapshot for given VM
    # @param [Integer] vmid - VM ID
    # @param [Integer] snapid - Snapshot ID
    # @param [Boolean] log - Making no logs if false
    # @return [nil | OpenNebula::Error]
    def RMSnapshot(vmid, snapid, log = true)
        LOG_STAT()
        LOG "Deleting snapshot(ID: #{snapid.to_s}) for VM#{vmid.to_s}", "SnapController" if log
        onblock(VirtualMachine, vmid.to_i).snapshot_delete(snapid.to_i)
    end
    # Making new snapshot for given VM with given name
    # @param [Integer] vmid - VM ID
    # @param [String] name - Name for new VM
    # @param [Boolean] log - Making no logs if false
    # @return [Integer | OpenNebula::Error] New snapshot ID
    def MKSnapshot(vmid, name, log = true)
        LOG_STAT()
        LOG "Snapshot create-query accepted", 'SnapController' if log
        return onblock(VirtualMachine, vmid.to_i).snapshot_create(name)
    end
    # Reverts choosen snapshot for given VM
    # @param [Integer] vmid - VM ID
    # @param [Integer] snapid - Snapshot ID
    # @param [Boolean] log - Making no logs if false
    # @return [nil | OpenNebula::Error]
    def RevSnapshot(vmid, snapid, log = true)
        LOG_STAT()
        LOG "Snapshot revert-query accepted", 'SnapController' if log
        return onblock(VirtualMachine, vmid.to_i).snapshot_revert(snapid.to_i)
    end
end