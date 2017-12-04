########################################################
#        Методы для управления ВМ и Аккаунтами         #
########################################################


class WHMHandler
    def Suspend(params, log = true)
        LOG_STAT(__method__.to_s, time())
        if !params['force'] then
            LOG "Suspend query call params: #{params.inspect}", "Suspend" if !params['force']
            return nil if !params['force']
        end
        LOG "Params: #{params.inspect} | log = #{log}", "Suspend" if DEBUG
        LOG "Suspend query for User##{params['userid']} Accepted!", "Suspend" if log
        # Обработка ошибки нулевого пользователя, удалять root как-то некрасиво
        return "Poshel nahuj so svoimi nulami!!!" if params['userid'].to_i == 0
        # Удаление пользователя
        Delete(params['userid'])
        LOG "Suspending VM#{params['vmid']}", "Suspend" if log
        # Приостановление виртуальной машины
        get_pool_element(VirtualMachine, params['vmid'], @client).suspend
        return nil
    end
    def Unsuspend(params)
        LOG_STAT(__method__.to_s, time())        
        if !params['force'] then            
            LOG "Unsuspend query call params: #{params.inspect}", "Unsuspend" if !params['force']
            return nil if !params['force']
        end
        LOG "Params: #{params.inspect} | log = #{log}", "Unsuspend" if DEBUG
        LOG "Unuspending User #{params['login']} and VM ##{params['vmid']}", "Unsuspend"
        # Создание копии удаленного(приостановленного) аккаунта
        userid = UserCreate(params['login'], params['password'], params['groupid'].to_i, @client)
        vm = get_pool_element(VirtualMachine, params['vmid'], @client)
        # Отдаем машину новой учетке
        vm.chown(userid, USERS_GROUP)
        # Запускаем машину
        vm.resume
        user = get_pool_element(User, userid, @client)
        # user = User.new(User.build_xml(userid), @client)
        # Получение информации о квотах пользователя
        used = (user.info! || user.to_hash)['USER']['VM_QUOTA']['VM']
        # Установление квот на уровень количества ресурсов выданных пользователю
        user.set_quota("VM=[ CPU=\"#{used['CPU_USED']}\", MEMORY=\"#{used['MEMORY_USED']}\", SYSTEM_DISK_SIZE=\"-1\", VMS=\"#{used['VMS_USED']}\" ]")    
        return { 'userid' => userid }
    end
    def Reboot(vmid = nil)
        LOG_STAT(__method__.to_s, time())        
        LOG "Rebooting VM#{vmid}", "Reboot"
        LOG "Params: vmid = #{vmid}", "Reboot" if DEBUG
        get_pool_element(VirtualMachine, vmid, @client).reboot(true) # true означает, что будет вызвана функция reboot-hard
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
        get_pool_element(VirtualMachine, vmid, @client).resume
    end
    def RMSnapshot(vmid, snapid, log = true)
        LOG_STAT(__method__.to_s, time())
        LOG "Deleting snapshot(ID: #{snapid.to_s}) for VM#{vmid.to_s}", "RMSnapshot" if log
        get_pool_element(VirtualMachine, vmid.to_i, @client).snapshot_delete(snapid.to_i)
    end
    def MKSnapshot(vmid, name, log = true)
        LOG_STAT(__method__.to_s, time())
        LOG "Snapshot create-query accepted", 'MKSnapshot' if log
        return get_pool_element(VirtualMachine, vmid.to_i, @client).snapshot_create(name)
    end
    def RevSnapshot(vmid, snapid, log = true)
        LOG_STAT(__method__.to_s, time())
        LOG "Snapshot revert-query accepted", 'RevSnapshot' if log
        return get_pool_element(VirtualMachine, vmid.to_i, @client).snapshot_revert(snapid.to_i)
    end
end