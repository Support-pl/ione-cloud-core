require 'rubygems'
require 'zmqjsonrpc'
require './service/quotagen.rb'
# require 'passgen'
# require './service/VMData.rb'
require './service/template_helper.rb'

###########################################
# Setting up Enviroment                   #
###########################################
ONE_LOCATION=ENV["ONE_LOCATION"]
if !ONE_LOCATION
    RUBY_LIB_LOCATION="/usr/lib/one/ruby"
else
    RUBY_LIB_LOCATION=ONE_LOCATION+"/lib/ruby"
end
$: << RUBY_LIB_LOCATION
require "opennebula"
include OpenNebula
###########################################
# OpenNebula credentials
CREDENTIALS = "oneadmin:Nhb500Gznmcjn"
# XML_RPC endpoint where OpenNebula is listening
ENDPOINT    = "http://localhost:2633/RPC2"
client = Client.new(CREDENTIALS, ENDPOINT)

require './service/ON_API/main.rb'

class WHMHandler
    def initialize(client)
        @client = client
    end
    def Test(msg)
        puts "Your message: #{msg}"
    end

    def NewAccount(clientid, login, pass, vmquota, os, cpu, memory, disk) # Хэндлер создания нового аккаунта PaaS и деплой машины в него
        puts "New Account Order Accepted!"
        # login = String.new()
        #pass = Passgen::generate( :length => 12, :symbols => true)
        # for i in 0..logb.size do # Создание логина на основе почты
        #     if logb[i] == "@" then break end
        #     login += logb[i]
        # end

        puts "Generating Quota"
        quota = NewQuota(login, vmquota, disk) # Генерирование квоты для нового пользователя
        puts "Creating new user - #{login}"
        userid, errors = UserCreate(login, pass, quota, @client)
        puts "Creating VM for #{login}"
        vmid = VMCreate(login, userid, "debian8", @client, cpu, memory) # Получение vmid только что созданной машины
        return ip = 0, vmid, userid, errors # Возврат в WHMCS IP-адреса и VMID машины, ID пользователя ON и массив ошибок
    end
    
end

WHMCS = WHMHandler.new(client) # Создание экземпляра хэндлер-сервера
server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:8080") # Создание экземпляра сервера
server.server_loop # Запуск сервера