require 'json'

class WHMHandler
    def initialize(client)
        @client = client
    end
    def Test(msg)
        LOG "Test message received, text: #{msg}", "Test"
        if msg == "PING" then
            return "PONG"
        end
        return "DONE"
    end

    def NewAccount(login, pass, templateid, groupid)
        LOG "New Account for #{login} Order Accepted!", "NewAccount"
        LOG "Creating new user for #{login}", "NewAccount"
        login, pass, templateid, groupid = login.to_s, pass.to_s, templateid.to_i, groupid.to_i
        userid = UserCreate(login, pass, groupid, @client)
        LOG "Creating VM for #{login}", "NewAccount"
        vmid = VMCreate(userid, templateid, @client, false) # Получение vmid только что созданной машины
        ip = GetIP(vmid)
        LOG "VM#{vmid} received the next IP: #{ip}", "NewAccount"
        return ip, vmid, userid
    end
    def Suspend(userid, vmid = nil)
        LOG "Suspend query for User##{userid} Accepted!", "Suspend"
        if userid == nil && vmid == nil then
            LOG "Suspend query rejected! 2 of 2 params are nilClass!", "Suspend"
            return 1
        elsif userid == 0 then
            LOG "Suspend query rejected! Tryed to block root-user(oneadmin)", "Suspend"
            return 1
        end
        LOG "Changing AuthDriver of user #{userid} to 'public'", "Suspend"
        user = User.new(User.build_xml(userid), @client)
        user.chauth("public")
        if vmid == nil then
            return nil
        end
        LOG "Suspending VM#{vmid}", "Suspend"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.suspend
        return nil
    end
    def Unsuspend(userid, vmid = nil)
        LOG "Resume query for User##{userid} Accepted!", "Unsuspend"
        if userid == nil && vmid == nil then
            LOG "Resume query rejected! 2 of 2 params are nilClass!", "Unsuspend"
            return 1
        end
        LOG "Changing AuthDriver of user #{userid} to 'core'", "Unsuspend"
        user = User.new(User.build_xml(userid), @client)
        user.chauth("core")
        if vmid == nil then
            return nil
        end
        LOG "Resuming VM#{vmid}", "Unsuspend"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.resume
    end
    def Reboot(vmid)
        LOG "Rebooting VM#{vmid}", "Reboot"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.reboot
    end
    def Terminate(userid, vmid = nil)
        if userid == nil || vmid == nil then
            LOG "Terminate query rejected! 1 of 2 params is nilClass!", "Terminate"
            return 1
        elsif userid == 0 then
            LOG "Terminate query rejected! Tryed to delete root-user(oneadmin)", "Terminate"
        end
        Delete(userid)
        LOG "Terminating VM#{vmid}", "Terminate"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.shutdown
    end
    def Shutdown(vmid)
        LOG "Shutting down VM#{vmid}", "Shutdown"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.poweroff
    end
    def Release(vmid)
        LOG "New Release Order Accepted!", "Release"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.release # <- Release
    end
    def Delete(userid)
        if userid == 0 then
            LOG "Delete query rejected! Tryed to delete root-user(oneadmin)", "Delete"
        end
        LOG "Deleting User ##{userid}", "Delete"
        user = User.new(User.build_xml(userid), @client)
        user.delete
    end
    def VM_XML(vmid)
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.monitoring_xml
    end
    def activity_log()
        LOG "Log file content has been copied remotely", "activity_log"
        log = File.read("#{ROOT}/log/activities.log")
        return log
    end
    def Resume(vmid)
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.resume
    end
    def GetIP(vmid)
        doc = Nokogiri::XML(VM_XML(vmid))
        address = ""
        doc.xpath('//GUEST_IP').each do |content| 
            address = content.text.to_s 
        end
        return address
    end
    def RMSnapshot(vmid, snapid)
        LOG "Deleting snapshot(ID: #{snapid}) for VM#{vmid}", "RMSnapshot"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.snapshot_delete(snapid)
    end
    def test()
        LOG("kjasjhfjasb", "test")
	return "YEP!"
    end
    def stop(passwd)
        LOG "Trying to stop server manually", "stop"
        if(passwd.crypt == "keLa9zoht45RY") then
            LOG "Server Stopped Manualy", "stop"
            Kernel.abort("[ #{time()} ] Server Stopped Remotely")
        end
        return nil
    end
    # def NewAccount(billingid, login, pass, vmquota, os, cpu, memory, disk) # Хэндлер создания нового аккаунта PaaS и деплой машины в него
    #     puts "[ #{time()} ] New Account for #{billingid} Order Accepted!"
    #     puts "[ #{time()} ] Generating Quota for #{billingid}"
    #     quota = NewQuota(login, vmquota, cpu, memory, disk) # Генерирование квоты для нового пользователя
    #     puts "[ #{time()} ] Creating new user for #{billingid} - #{login}"
    #     userid = UserCreate(login, pass, quota, @client)
    #     puts "[ #{time()} ] Creating VM for #{billingid}"
    #     vmid = VMCreate(login, billingid, userid, os, @client, cpu, memory) # Получение vmid только что созданной машины
    #     ip = GetIP(vmid)
    #     return ip, vmid, userid # Возврат в WHMCS IP-адреса и VMID машины, ID пользователя ON
    # end

end