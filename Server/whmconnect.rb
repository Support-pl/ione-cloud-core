require 'rubygems'
require 'zmqjsonrpc'
require './service/quotagen.rb'
require 'passgen'
require './service/VMData.rb'

class WHMHandler
    def NewAccount(clientid, logb, pass, vmquota, os, cpu, memory, disk)
        login = String.new()
        #pass = Passgen::generate( :length => 12, :symbols => true)
        for i in 0..logb.size do
            if logb[i] == "@" then break end
            login += logb[i]
        end
        quota = NewQuota(login + clientid.to_s, vmquota,[cpu, memory, disk])
        puts "Creating account> oneuser create #{login} #{pass}"
        puts "Creating account> oneuser chgrp #{login} Users"
        puts "Creating account> oneuser quota #{login} #{quota}"
        puts "Creating VM>"
        vmid = GetVMID(`sh onevm create dir/to/templates/#{os} --name #{login + clientid.to_s} --cpu #{cpu} --memory #{memory}`)
        ip = GetIP(vmid)
        puts "onevm chown #{vmid} #{login}"
        return ip, vmid
    end

    def RmAccount(logb, vmid)
        result = true
        puts(vmid.size - 1)
        for i in 0..vmid.size - 1 do
            delete_vm = puts("onevm recover --delete #{vmid}")
            result = (result and delete_vm)
        end
        login = String.new()
        for i in 0..logb.size do
            if logb[i] == "@" then break end
            login += logb[i]
        end
        delete_user = puts("oneuser delete #{login}")
        return not(result and delete_user)
    end 

    def AddVM(clientid, logb, vmquota, os, cpu, memory, disk)
        login = String.new()
        for i in 0..logb.size do
            if logb[i] == "@" then break end
            login += logb[i]
        end
        quota = NewQuota(login + clientid.to_s, vmquota, [cpu, memory, disk])
        puts "Creating account> oneuser quota #{login} #{quota}"
        puts "Creating VM>"
        vmid = GetVMID(`sh onevm create dir/to/templates/#{os} --name #{login + clientid.to_s} --cpu #{cpu} --memory #{memory}`)
        ip = GetIP(vmid)
        puts "onevm chown #{vmid} #{login}"        
        return ip, vmid
    end
    
    def Terminate(vdsip)
        puts "Server " + vdsip + " terminated succsesfully"
        return "succss"
    end
end

WHMCS = WHMHandler.new()
server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:8080")
server.server_loop