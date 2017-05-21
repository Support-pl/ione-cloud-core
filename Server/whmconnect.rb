require 'rubygems'
require 'zmqjsonrpc'
require './service/quotagen.rb'
require 'passgen'
require './service/VMData.rb'
require './service/template_helper.eb'
require './service/ON_API/main.rb'

class WHMHandler
    def NewAccount(clientid, logb, pass, vmquota, os, cpu, memory, disk) # Хэндлер создания нового аккаунта PaaS и деплой машины в него
        login = String.new()
        #pass = Passgen::generate( :length => 12, :symbols => true)
        for i in 0..logb.size do # Создание логина на основе почты
            if logb[i] == "@" then break end
            login += logb[i]
        end
        quota = NewQuota(login + clientid.to_s, vmquota, disk) # Генерирование квоты для нового пользователя
        puts "Creating new user #{login}..."
        UserCreate(login, pass, quota)
        puts "Creating VM>"
        vmid = GetVMID(`echo sh onetemplate instantiate #{GetTemplate(os)} --user oneadmin --name size-test --cpu 2 --memory 2048 --hold`) # Получение vmid только что созданной машины
        ip = GetIP(vmid) # Получение IP-адреса новой машины
        puts "onevm chown #{vmid} #{login}" # Передача машины новому пользователю
        return ip, vmid # Возврат в WHMCS IP-адреса и VMID машины
    end

    def Terminate(logb, vmid) # Хэндлер удаления аккаунта PaaS
        for i in 0..vmid.size - 1 do # Удаление всех машин пользователя
            puts("onevm recover --delete #{vmid}")
        end
        login = String.new() 
        for i in 0..logb.size do # Получение логина на основе почты
            if logb[i] == "@" then break end
            login += logb[i]
        end
        puts("oneuser delete #{login}") # Удаление 
        return true
    end 

    def AddVM(clientid, logb, vmquota, os, cpu, memory, disk) # Добавление машины в существующий аккаунт
        login = String.new() # Получение логина
        for i in 0..logb.size do
            if logb[i] == "@" then break end
            login += logb[i]
        end
        quota = NewQuota(login + clientid.to_s, vmquota, disk) # Генерация новой квоты для пользователя
        puts "Creating account> oneuser quota #{login} #{quota}" # Расширение квоты пользователя
        puts "Creating VM>"
        vmid = GetVMID(`sh onevm create dir/to/templates/#{os} --name #{login + clientid.to_s} --cpu #{cpu} --memory #{memory}`) # Создание новой машины и запись ее vmid
        ip = GetIP(vmid) # Получение IP-адреса новой машины
        puts "onevm chown #{vmid} #{login}" # Смена владельца на требуемого пользователя
        return ip, vmid # Возврат IP-адреса и VMID новой машины
    end
    
end

WHMCS = WHMHandler.new() # Создание экземпляра хэндлер-сервера
server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:8080") # Создание экземпляра сервера
server.server_loop # Запуск сервера