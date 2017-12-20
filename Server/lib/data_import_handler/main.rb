class WHMHandler
    def IMPORT(username, credentials, vmid, group)
        userid = UserCreate(username, credentials, group, @client)
        vm = get_pool_element(VirtualMachine, vmid, @client)
        vm.chown(userid, USERS_GROUP)
        return userid
    end
end