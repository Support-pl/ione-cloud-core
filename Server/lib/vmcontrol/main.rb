########################################################
#        Методы для управления ВМ и Аккаунтами         #
########################################################

puts 'Extending Handler class by commerce-useful methods'
class WHMHandler
    def Suspend(params, log = true, trace = ["Suspend method called:#{__LINE__}"])
        begin
            LOG_STAT(__method__.to_s, time())
            proc_id = proc_id_gen(__method__)
            if !params['force'] then
                LOG "Suspend query call params: #{params.inspect}", "Suspend" if !params['force']
                return kill_proc(proc_id) || nil if !params['force']
            end
            LOG "Params: #{params.inspect} | log = #{log}", "Suspend" if DEBUG
            # Удаление пользователя
            LOG "Suspending VM#{params['vmid']}", "Suspend" if log
            # Приостановление виртуальной машины
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
            return kill_proc(proc_id) || 0
        rescue => e
            return e.message, trace
        end
    end
    def SuspendVM(vmid)
        onblock(VirtualMachine, vmid.to_i).suspend
    end        
    def Unsuspend(params, trace = ["Unsuspend method called:#{__LINE__}"])
        begin
            LOG_STAT(__method__.to_s, time())
            proc_id = proc_id_gen(__method__)
            LOG "Unuspending VM ##{params['vmid']}", "Unsuspend"
            trace << "Creating VM object:#{__LINE__ + 1}"            
            onblock(VirtualMachine, params['vmid'].to_i) do | vm |
                trace << "Unsuspending VM:#{__LINE__ + 1}"                
                vm.resume
                if !params['force'] then            
                    LOG "Unsuspend query call params: #{params.inspect}", "Unsuspend" if !params['force']
                    return kill_proc(proc_id) || nil if !params['force']
                end
                trace << "Changing user rights:#{__LINE__ + 1}"                
                vm.chmod(
                    -1,  1, -1,
                    -1, -1, -1,
                    -1, -1, -1
                )
            end
            trace << "Killing proccess:#{__LINE__ + 1}"            
            return kill_proc(proc_id) || 0
        rescue => e
            return e.message, trace
        end
    end
    def Reboot(vmid = nil, hard = true)
        LOG_STAT(__method__.to_s, time())
        proc_id = proc_id_gen(__method__)          
        return "VMID cannot be nil!" if vmid.nil?     
        LOG "Rebooting VM#{vmid}", "Reboot"
        LOG "Params: vmid = #{vmid}, hard = #{hard}", "Reboot" if DEBUG
        return kill_proc(proc_id) || onblock(VirtualMachine, vmid.to_i).reboot(hard) # true означает, что будет вызвана функция reboot-hard
    end
    def Terminate(userid, vmid, force = false)
        LOG_STAT(__method__.to_s, time())
        proc_id = proc_id_gen(__method__)          
        LOG "Terminate query call params: {\"userid\" => #{userid}, \"vmid\" => #{vmid}}", "Terminate"
        return nil if !force
        # Пробуем НЕ удалить корень
        if userid == nil || vmid == nil then
            LOG "Terminate query rejected! 1 of 2 params is nilClass!", "Terminate"
            return 1
        elsif userid == 0 then
            LOG "Terminate query rejected! Tryed to delete root-user(oneadmin)", "Terminate"
        end
        # Удаляем пользователя
        Delete(userid)
        LOG "Terminating VM#{vmid}", "Terminate"
        onblock(VirtualMachine, vmid).recover 3 # recover с параметром 3 означает полное удаление с диска
        kill_proc(proc_id)
    end
    def Shutdown(vmid) # Выключение машины
        LOG_STAT(__method__.to_s, time())
        proc_id = proc_id_gen(__method__)        
        LOG "Shutting down VM#{vmid}", "Shutdown"
        return kill_proc(proc_id) || onblock(VirtualMachine, vmid).poweroff
    end
    def Release(vmid)
        LOG_STAT(__method__.to_s, time())
        LOG "New Release Order Accepted!", "Release"
        onblock(VirtualMachine, vmid).release
    end
    def Delete(userid) # Удаление пользователя
        LOG_STAT(__method__.to_s, time())
        if userid == 0 then
            LOG "Delete query rejected! Tryed to delete root-user(oneadmin)", "Delete"
        end
        LOG "Deleting User ##{userid}", "Delete"
        onblock(User, userid).delete
    end
    def Resume(vmid)
        LOG_STAT(__method__.to_s, time())
        return onblock(VirtualMachine, vmid.to_i).resume
    end
end