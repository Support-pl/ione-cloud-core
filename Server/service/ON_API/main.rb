def UserCreate(login, pass, quota, client)
    errors = Array.new(0, String) # Массив message объектов OpenNebula::Error ошибок
    user = User.new(User.build_xml(100), client) # Генерирование объекта User на основе шаблонного пользователя группы PaaS

    begin
        allocation_result = user.allocate(login, pass) # Создание и размещение в пул нового пользователя login:pass
    rescue => e
        errors.insert(0, e.message) # Обработка исключения "NAME is already taken by User ...."
        return 0, errors
    end

    if allocation_result != nil then errors.insert(0, allocation_result.message) end # В случае неудачного размещения будет ошибка, при удачном nil
    chgrp_result = user.chgrp(157) # Смена группы пользователя ( 157 - группа PaaS )
    if chgrp_result != nil then errors.insert(0, chgrp_result.message) end # В случае ошибки при смене группы будет ошибка, порядок == nil 
    quota = user.set_quota(quota) # Настройка квоты пользователя
    if quota != nil then errors.insert(0, quota.message) end # В случае ошибки квотирования будет ошибка, успех == nil
    return user.id, errors
end

# def VMCreate(login, userid, os, client, cpu = 2, memory = 1024)  
#     vmtempl = Template.new(Template.build_xml(), client)
#     puts vmtempl.id
#     begin
#         vmid = # Или разобрать client.call или завести Template.instantiate!
#     rescue => exc
#         return exc.message
#     end
# end