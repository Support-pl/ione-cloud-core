def UserCreate(login, pass, quota, client)
    user = User.new(User.build_xml(100), client)
    userid = user.allocate(login, pass)
    user.chgrp(157)
    user.set_quota(quota) # Рефикснуть
    return user.id
end

def VMCreate(login, userid, os, client, cpu = 2, memory = 1024)  
    vmtempl = Template.new(Template.build_xml("47"), client)
    puts vmtempl.id
    begin
        vmid = # Или разобрать client.call или завести Template.instantiate!
    rescue => exc
        return exc.message
    end
end