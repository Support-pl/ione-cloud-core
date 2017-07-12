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
    chgrp_result = user.chgrp(1) # Смена группы пользователя ( 157 - группа PaaS )
    if chgrp_result != nil then errors.insert(0, chgrp_result.message) end # В случае ошибки при смене группы будет ошибка, порядок == nil 
    quota = user.set_quota(quota) # Настройка квоты пользователя
    if quota != nil then errors.insert(0, quota.message) end # В случае ошибки квотирования будет ошибка, успех == nil
    return user.id, errors
end

def VMCreate(login, billingid, userid, os, client, cpu = 2, memory = 1024)
    errors = Array.new(0, String)
    template = Template.new(Template.build_xml(os), client) # os - номер шаблона
    begin
        vmid = template.instantiate(login + "_" + billingid.to_s, true) # деплой машины из шаблона №os, true означает, что машина не будет деплоится сразу, а создасться в состоянии HOLD
    rescue => exception
        return exception.message
    end
    begin
        puts vmid.message
    rescue => e
    end
    vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), client)
    chown_result = vm.chown(userid, 1) # Убедиться что срабатывает + настроить группы
    if chown_result != nil
        errors.insert(0, chown_result.message)
    end
    vm.resize( # Надо тестить
        "CPU=\"#{cpu}\"
        MEMORY=\"#{memory}\"
        VCPU=\"1\"",
        true
    )
    # vm.release # Непосредственно деплой, т.н. смена состояния с HOLD на ACTIVE
    xml = Nokogiri::XML(vm.monitoring_xml)
    sleep(1) until vm.lcm_state_str != "BOOT"
    begin
        ip = xml.xpath('//GUEST_IP').content #!!!!!
    rescue => e
        puts "[ #{time()} ] " + e.message
        ip = "ERROR_OCCURRED"
    end
    return vmid, errors, ip
end