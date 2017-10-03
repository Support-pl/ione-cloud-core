require 'nori'

DEFAULT_HOST = CONF['OpenNebula']['default-node-id'] # ID хоста vOne - используется как цель для деплоя машин

def UserCreate(login, pass, groupid, client)
    user = User.new(User.build_xml(0), client) # Генерирование объекта User на основе шаблонного пользователя группы PaaS
    begin
        allocation_result = user.allocate(login, pass, "core", [USERS_GROUP, groupid]) # Создание и размещение в пул нового пользователя login:pass
    rescue => e
        raise e.message
        return 0
    end

    LOG allocation_result.message if allocation_result != nil # В случае неудачного размещения будет ошибка, при удачном nil
    return user.id
end

def Win?(templateid, client)
    template = Template.new(Template.build_xml(templateid), client)
    template.info!
    return Nori.new.parse(template.to_xml)['VMTEMPLATE']['NAME'].include?('Windows_server')
end

def VMCreate(userid, user_login, templateid, passwd, client, release)
    template = Template.new(Template.build_xml(templateid), client) # os - номер шаблона
    begin
        vmid = template.instantiate("#{user_login}_vm", true) # деплой машины из шаблона №os, true означает, что машина не будет деплоится сразу, а создасться в состоянии HOLD
    rescue => exception
        raise exception.message
        return 0
    end
    begin
        raise vmid.message
    rescue => e
    end
    vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), client)
    chown_result = vm.chown(userid, USERS_GROUP)
    raise chown_result.message if chown_result != nil
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
    user = User.new(User.build_xml(userid), client)
    user.info!
    used = Nori.new.parse(user.to_xml)['USER']['VM_QUOTA']['VM']
    user.set_quota("VM=[ CPU=\"#{used['CPU_USED']}\", MEMORY=\"#{used['MEMORY_USED']}\", SYSTEM_DISK_SIZE=\"-1\", VMS=\"#{used['VMS_USED']}\" ]")
    return vmid
end