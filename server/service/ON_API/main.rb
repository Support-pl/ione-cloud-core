def UserCreate(login, pass, groupid = nil, client = $client, object = false)
    user = User.new(User.build_xml(0), client) # Генерирование объекта User на основе шаблонного пользователя группы PaaS
    groupid = nil
    begin
        allocation_result = user.allocate(login, pass, "core", groupid.nil? ? [USERS_GROUP] : [USERS_GROUP, groupid]) # Создание и размещение в пул нового пользователя login:pass
    rescue => e
        raise e.message
        return 0
    end

    LOG allocation_result.message, 'DEBUG' if !allocation_result.nil? # В случае неудачного размещения будет ошибка, при удачном nil
    return user.id, user if object
    return user.id
end

def Win?(templateid, client)
    onblock('temp', templateid, client) do | t |
        t.info!
        name = t.to_hash['VMTEMPLATE']['NAME']
        return name.include?('Windows_server') || name.include?('Win_Server')
    end
end

def VMCreate(userid, user_login, templateid, passwd, client, release = true)
    template = Template.new(Template.build_xml(templateid), client) # os - номер шаблона
    begin
        vmid = template.instantiate("#{user_login}_vm", true) # деплой машины из шаблона №os, true означает, что машина не будет деплоится сразу, а создасться в состоянии HOLD
    rescue => exception
        raise exception.message
        return 0
    end

    raise vmid.message if vmid.class != Fixnum

    vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), client)
    
    if Win? templateid, client then
        vm.updateconf(
            "CONTEXT = [ NETWORK=\"YES\", PASSWORD = \"#{passwd}\", SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\", USERNAME = \"Administrator\" ]"
        )
        vm.updateconf(
            "GRAPHICS = [ LISTEN=\"0.0.0.0\", PORT=\"#{CONF['OpenNebula']['base-vnc-port'] + vmid}\", TYPE=\"VNC\" ]"
        )
    else
        vm.updateconf(
            "CONTEXT = [ NETWORK=\"YES\", PASSWORD = \"#{passwd}\", SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\" ]"
        ) # Настройка контекста: изменение root-пароля на заданный
        vm.updateconf(
            "GRAPHICS = [ LISTEN=\"0.0.0.0\", PORT=\"#{CONF['OpenNebula']['base-vnc-port'] + vmid}\", TYPE=\"VNC\" ]"
        ) # Настройка порта для VNC
    end
    if release then
        vm.release # Смена состояния с HOLD на Pending
        vm.deploy DEFAULT_HOST # Деплой машины
    end

    user = onblock(User, userid)
    used = (vm.info! || vm.to_hash)['VM']['TEMPLATE']
    user_quota = (user.info! || user.to_hash)['USER']['VM_QUOTA']
    if user_quota.nil? then
        user_quota = user_quota['VM']
        user_quota = Hash.new
    end
    user.set_quota("VM=[
                    CPU=\"#{(used['CPU'].to_i + user_quota['CPU_USED'].to_i).to_s}\", 
                    MEMORY=\"#{(used['MEMORY'].to_i + user_quota['MEMORY_USED'].to_i).to_s}\", 
                    SYSTEM_DISK_SIZE=\"-1\", 
                    VMS=\"#{(user_quota['VMS_USED'].to_i + 1).to_s}\" ]")

    chown_result = vm.chown(userid, USERS_GROUP)
    LOG chown_result.message if chown_result != nil
    raise if chown_result != nil
    return vmid
end