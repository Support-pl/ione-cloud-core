########################################################
#        Методы для управления ВМ и Аккаунтами         #
########################################################

puts 'Extending Handler class by commerce-useful methods'
class WHMHandler
    def Suspend(params, log = true)
        LOG_STAT(__method__.to_s, time())
        proc_id = proc_id_gen(__method__)
        if !params['force'] then
            LOG "Suspend query call params: #{params.inspect}", "Suspend" if !params['force']
            return nil if !params['force']
        end
        LOG "Params: #{params.inspect} | log = #{log}", "Suspend" if DEBUG
        # Удаление пользователя
        LOG "Suspending VM#{params['vmid']}", "Suspend" if log
        # Приостановление виртуальной машины
        vm = get_pool_element(VirtualMachine, params['vmid'].to_i, @client)
        vm.suspend
        vm.chmod(
            -1,  0, -1,
            -1, -1, -1,
            -1, -1, -1
        )
        return kill_proc(proc_id) || 0
    end
    def SuspendVM(vmid)
        get_pool_element(VirtualMachine, vmid.to_i, @client).suspend
    end        
    def Unsuspend(params)
        LOG_STAT(__method__.to_s, time())
        proc_id = proc_id_gen(__method__)  
        vm = get_pool_element(VirtualMachine, params['vmid'].to_i, @client)
        vm.resume
        if !params['force'] then            
            LOG "Unsuspend query call params: #{params.inspect}", "Unsuspend" if !params['force']
            return nil if !params['force']
        end
        LOG "Unuspending VM ##{params['vmid']}", "Unsuspend"
        vm.chmod(
            -1,  1, -1,
            -1, -1, -1,
            -1, -1, -1
        )
        return kill_proc(proc_id) || 0
    end
    def Reboot(vmid = nil, hard = true)
        LOG_STAT(__method__.to_s, time())
        proc_id = proc_id_gen(__method__)          
        return "VMID cannot be nil!" if vmid.nil?     
        LOG "Rebooting VM#{vmid}", "Reboot"
        LOG "Params: vmid = #{vmid}, hard = #{hard}", "Reboot" if DEBUG
        return kill_proc(proc_id) || get_pool_element(VirtualMachine, vmid.to_i, @client).reboot(hard) # true означает, что будет вызвана функция reboot-hard
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
        get_pool_element(VirtualMachine, vmid, @client).recover 3 # recover с параметром 3 означает полное удаление с диска
        kill_proc(proc_id)
    end
    def Shutdown(vmid) # Выключение машины
        LOG_STAT(__method__.to_s, time())
        proc_id = proc_id_gen(__method__)        
        LOG "Shutting down VM#{vmid}", "Shutdown"
        return kill_proc(proc_id) || get_pool_element(VirtualMachine, vmid, @client).poweroff
    end
    def Release(vmid)
        LOG_STAT(__method__.to_s, time())
        LOG "New Release Order Accepted!", "Release"
        get_pool_element(VirtualMachine, vmid, @client).release
    end
    def Delete(userid) # Удаление пользователя
        LOG_STAT(__method__.to_s, time())
        if userid == 0 then
            LOG "Delete query rejected! Tryed to delete root-user(oneadmin)", "Delete"
        end
        LOG "Deleting User ##{userid}", "Delete"
        get_pool_element(User, userid, @client).delete
    end
    def Resume(vmid)
        LOG_STAT(__method__.to_s, time())
        return get_pool_element(VirtualMachine, vmid.to_i, @client).resume
    end
end