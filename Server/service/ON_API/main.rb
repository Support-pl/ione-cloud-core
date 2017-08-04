
PaaS_group_id = 1

def UserCreate(login, pass, groupid, client)
    user = User.new(User.build_xml(1), client) # Генерирование объекта User на основе шаблонного пользователя группы PaaS
    begin
        allocation_result = user.allocate(login, pass, "core", [USERS_GROUP, groupid]) # Создание и размещение в пул нового пользователя login:pass
    rescue => e
        raise e.message
        return 0
    end

    if allocation_result != nil then 
        LOG allocation_result.message # В случае неудачного размещения будет ошибка, при удачном nil
    end
    return user.id
end

def VMCreate(userid, templateid, client, release = true)
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
    chown_result = vm.chown(userid, PaaS_group_id) # Убедиться что срабатывает + настроить группы
    if chown_result != nil then
        raise chown_result.message
    end

    if release then
        vm.release # Непосредственно деплой, т.н. смена состояния с HOLD на ACTIVE
    end
    return vmid
end
# def VMCreate(login, billingid, userid, os, client, cpu = 2, memory = 1024, release = true)
#     template = Template.new(Template.build_xml(os), client) # os - номер шаблона
#     begin
#         vmid = template.instantiate(login + "_" + billingid.to_s, true) # деплой машины из шаблона №os, true означает, что машина не будет деплоится сразу, а создасться в состоянии HOLD
#     rescue => exception
#         raise exception.message
#         return 0
#     end
#     begin
#         raise vmid.message
#     rescue => e
#     end
#     vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), client)
#     chown_result = vm.chown(userid, 1) # Убедиться что срабатывает + настроить группы
#     if chown_result != nil
#         raise chown_result.message
#     end
#     vm.resize( # Надо тестить
#         "CPU=\"#{cpu}\"
#         MEMORY=\"#{memory}\"
#         VCPU=\"1\"",
#         true
#     )
#     if release then
#         vm.release 
#     end # Непосредственно деплой, т.н. смена состояния с HOLD на ACTIVE
#     return vmid
# end