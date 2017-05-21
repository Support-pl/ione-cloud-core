def UserCreate(login, pass, quota, client)
    user = User.new(User.build_xml(100), client)
    userid = user.allocate(login, pass)
    user.chgrp(157)
    user.set_quota(quota)
    return user.id
end

def VMCreate(login, userid, os, client, cpu = 2, memory = 1024)  
    
end