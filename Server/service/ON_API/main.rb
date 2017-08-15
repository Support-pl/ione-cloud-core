
PaaS_group_id = 1 # Группа пользователей PaaS
VONE_ID = 0 # ID хоста vOne - используется как цель для деплоя машин

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

def VMCreate(userid, templateid, passwd, client, release = true)
    template = Template.new(Template.build_xml(templateid), client) # os - номер шаблона
    begin
        vmid = template.instantiate("user_#{userid}_vm", true) # деплой машины из шаблона №os, true означает, что машина не будет деплоится сразу, а создасться в состоянии HOLD
    rescue => exception
        raise exception.message
        return 0
    end
    begin
        raise vmid.message
    rescue => e
    end
    vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), client)
    chown_result = vm.chown(userid, PaaS_group_id)
    raise chown_result.message if chown_result != nil
    vm.updateconf(
        "CONTEXT = [ NETWORK=\"YES\", PASSWORD = \"#{passwd}\", SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\"]"
    ) # Настройка контекста: изменение root-пароля на заданный
    if release then
        vm.release # Смена состояния с HOLD на Pending
        vm.deploy VONE_ID # Деплой машины
    end
    return vmid
end