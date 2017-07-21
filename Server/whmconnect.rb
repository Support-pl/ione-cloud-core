require 'rubygems'
require 'zmqjsonrpc'
# require 'passgen'

$stderr = File.open("#{File.expand_path(File.dirname(__FILE__))}/log/errors.txt", "a")
$stdout = File.open("#{File.expand_path(File.dirname(__FILE__))}/log/activities.log", "a")
STDOUT.sync = true
puts "-----------------------------------------------------------"
ROOT = File.expand_path(File.dirname(__FILE__))
USERS_GROUP = 100

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

require "#{ROOT}/service/time.rb"
require "#{ROOT}/service/ON_API/main.rb"
require "#{ROOT}/service/handlers/WHMCS.rb"

`echo "[ #{time()} ] Initializing JSON-RPC Server..." >> #{ROOT}/log/activities.log`
WHMCS = WHMHandler.new(client) # Создание экземпляра хэндлер-сервера
server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:8008") # Создание экземпляра сервера
`echo "[ #{time()} ] Server initialized" >> #{ROOT}/log/activities.log`
server.server_loop # Запуск сервера