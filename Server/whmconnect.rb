require 'rubygems'
require 'zmqjsonrpc'
# require 'passgen'


ROOT = File.expand_path(File.dirname(__FILE__))
USERS_GROUP = 1

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
ENDPOINT = "http://localhost:2633/RPC2"
client = Client.new(CREDENTIALS, ENDPOINT)

require "#{ROOT}/service/time.rb"
require "#{ROOT}/service/log.rb"
require "#{ROOT}/service/ON_API/main.rb"
require "#{ROOT}/service/handlers/WHMCS.rb"

at_exit do
    LOG("Server was stoppped")
end

LOG("-----------------------------------------------------------", false)
LOG "Initializing JSON-RPC Server..."
WHMCS = WHMHandler.new(client) # Создание экземпляра хэндлер-сервера
server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:8008") # Создание экземпляра сервера
LOG "Server initialized"

# if ARGV[0] == "test" then
#     thread = Thread.new {
#         test_server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:8008")
#         test_server.server_loop
#     }
#     sleep(30)
#     thread.exit
# end

server.server_loop # Запуск сервера
