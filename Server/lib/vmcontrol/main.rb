########################################################
#        Методы для управления ВМ и Аккаунтами         #
########################################################


class WHMHandler
    def Suspend(params, log = true)
        LOG_STAT(__method__.to_s, time())
        installid = Time.now.to_i.to_s(16).crypt(params['login'])
        $proc << "Suspend#{installid}"
        at_exit do
            $proc.delete "Suspend#{installid}"
        end
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
        return 0
    end
    def SuspendVM(vmid)
        get_pool_element(VirtualMachine, vmid.to_i, @client).suspend
    end        
    def Unsuspend(params)
        LOG_STAT(__method__.to_s, time())
        installid = Time.now.to_i.to_s(16).crypt(params['login'])
        $proc << "Unsuspend#{installid}"
        at_exit do
            $proc.delete "Unsuspend#{installid}"
        end     
        if !params['force'] then            
            LOG "Unsuspend query call params: #{params.inspect}", "Unsuspend" if !params['force']
            return nil if !params['force']
        end
        LOG "Unuspending VM ##{params['vmid']}", "Unsuspend"
        vm = get_pool_element(VirtualMachine, params['vmid'].to_i, @client)
        vm.resume
        vm.chmod(
            -1,  1, -1,
            -1, -1, -1,
            -1, -1, -1
        )
        return 0
    end
    def Reboot(vmid = nil, hard = true)
        LOG_STAT(__method__.to_s, time())
        return "VMID cannot be nil!" if vmid.nil?     
        LOG "Rebooting VM#{vmid}", "Reboot"
        LOG "Params: vmid = #{vmid}, hard = #{hard}", "Reboot" if DEBUG
        get_pool_element(VirtualMachine, vmid.to_i, @client).reboot(hard) # true означает, что будет вызвана функция reboot-hard
    end
    def Terminate(userid, vmid, force = false)
        LOG_STAT(__method__.to_s, time())        
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
    end
    def Shutdown(vmid) # Выключение машины
        LOG_STAT(__method__.to_s, time())
        LOG "Shutting down VM#{vmid}", "Shutdown"
        get_pool_element(VirtualMachine, vmid, @client).poweroff
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
        get_pool_element(VirtualMachine, vmid.to_i, @client).resume
    end
end