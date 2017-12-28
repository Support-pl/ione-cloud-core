puts 'Extending Handler class by IMPORT func'
class WHMHandler
    def IMPORT(username, credentials, vmid, group)
        LOG username, 'DEBUG'
        LOG credentials, 'DEBUG'
        LOG vmid, 'DEBUG'
        LOG group, 'DEBUG'
        return nil
        userid = UserCreate(username, credentials, group, @client)
        vm = get_pool_element(VirtualMachine, vmid, @client)
        vm.chown(userid, USERS_GROUP)
        return userid
    end
end