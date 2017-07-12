require 'rubygems'
require 'zmqjsonrpc'
require './service/quotagen.rb'
# require 'passgen'
# require './service/VMData.rb'
require './service/template_helper.rb'
require './service/time.rb'

$stderr = File.open("log/errors.txt", "a")
$stdout = File.open("log/activities.txt", "a")
puts "-----------------------------------------------------------"
ROOT = "/root/Server/"

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
require './service/handlers/WHMCS.rb'

puts "[ #{time()} ] Initializing JSON-RPC Server..."
WHMCS = WHMHandler.new(client) # Создание экземпляра хэндлер-сервера
server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:8008") # Создание экземпляра сервера
puts "[ #{time()} ] Server initialized"
server.server_loop # Запуск сервера