# def UserCreate(login, pass, quota, client)
#     user = User.new(User.build_xml(1), client) # Генерирование объекта User на основе шаблонного пользователя группы PaaS

#     begin
#         allocation_result = user.allocate(login, pass, nil, USERS_GROUP) # Создание и размещение в пул нового пользователя login:pass
#     rescue => e
#         raise e.message
#         return 0
#     end

#     if allocation_result != nil then puts allocation_result.message end # В случае неудачного размещения будет ошибка, при удачном nil
#     chgrp_result = user.chgrp(1) # Смена группы пользователя ( 157 - группа PaaS )
#     if chgrp_result != nil then raise chgrp_result.messages end # В случае ошибки при смене группы будет ошибка, порядок == nil 
#     quota = user.set_quota(quota) # Настройка квоты пользователя
#     if quota != nil then puts quota.message end # В случае ошибки квотирования будет ошибка, успех == nil
#     return user.id
# end
def UserCreate(login, pass, groupid, client)
    user = User.new(User.build_xml(1), client) # Генерирование объекта User на основе шаблонного пользователя группы PaaS

    begin
        allocation_result = user.allocate(login, pass, nil, [USERS_GROUP, groupid]) # Создание и размещение в пул нового пользователя login:pass
    rescue => e
        raise e.message
        return 0
    end

    if allocation_result != nil then puts allocation_result.message end # В случае неудачного размещения будет ошибка, при удачном nil
    return user.id
end

def VMCreate(login, userid, templateid, groupid, client, release = true)
    template = Template.new(Template.build_xml(templateid), client) # os - номер шаблона
     begin
        vmid = template.instantiate(login + "_" + userid.to_s, true) # деплой машины из шаблона №os, true означает, что машина не будет деплоится сразу, а создасться в состоянии HOLD
    rescue => exception
        raise exception.message
        return 0
    end
    begin
        raise vmid.message
    rescue => e
    end
    vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), client)
    chown_result = vm.chown(userid, groupid) # Убедиться что срабатывает + настроить группы
    if chown_result != nil
        raise chown_result.message
    end

    if release then
        vm.release 
    end # Непосредственно деплой, т.н. смена состояния с HOLD на ACTIVE
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

# доки
# id группы из whmcs
# добавить unsuspend
# объединить delete и terminate
# защиту от дебилов
# запрет на удаление
# 