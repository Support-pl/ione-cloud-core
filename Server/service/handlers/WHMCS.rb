class WHMHandler
    def initialize(client)
        @client = client
    end
    def Test(msg)
        puts "[ #{time()} ] Test message received, text: #{msg}"
    end

    def NewAccount(login, pass, templateid, groupid)
        puts "[ #{time()} ] New Account for #{login} Order Accepted!"
        puts "[ #{time()} ] Creating new user for #{login}"
        userid = UserCreate(login, pass, groupid, @client)
        puts "[ #{time()} ] Creating VM for #{login}"
        vmid = VMCreate(login, userid, templateid, groupid, @client, false) # Получение vmid только что созданной машины
        ip = GetIP(vmid)
        return ip, vmid, userid
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
    def Suspend(userid, vmid)
        puts "[ #{time()} ] Suspending VM#{vmid}"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.suspend
        # puts "[ #{time()} ] Changing group of user #{userid} to SuspendedUsers"
        # user = User.new(User.build_xml(userid), @client)
        # user.chgrp(3) # Поправить число на номер группы SuspendedUsers
    end
    def Reboot(vmid)
        puts "[ #{time()} ] Rebooting VM#{vmid}"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.reboot
    end
    def Terminate(userid, vmid)
        puts "[ #{time()} ] Terminating VM#{vmid}"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.shutdown
        Delete(userid)
    end
    def Shutdown(vmid)
        puts "[ #{time()} ] Shutting down VM#{vmid}"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.poweroff
    end
    def Release(vmid)
        puts "[ #{time()} ] New Release Order Accepted!"
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.release # <- Release
    end
    def Delete(userid)
        puts "[ #{time()} ] Deleting User ##{userid}"
        user = User.new(User.build_xml(userid), @client)
        user.delete
    end
    # def StopServer(passwd)
    #     if(passwd == "Jago322==") then
    #         puts "[ #{time()} ] Server Stopped Manualy"
    #         Kernel.abort("[ #{time()} ] Server Stopped Remotely")
    #     end
    # end
    def VM_XML(vmid)
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        return vm.monitoring_xml
    end
    def activity_log()
        puts "[ #{time()} ] Log file content has been copied remotely"
        log = File.open("#{ROOT.chomp!}/log/activities.log", "rb") { |line| line.read }
        return log
    end
    def Resume(vmid)
        vm = VirtualMachine.new(VirtualMachine.build_xml(vmid), @client)
        vm.resume
    end
    def GetIP(vmid)
        doc = Nokogiri::XML(VM_XML(vmid))
        address = ""
        doc.xpath('//GUEST_IP').each do |content| address = content.text.to_s end
        return address
    end
end