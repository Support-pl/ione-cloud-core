require 'zmqjsonrpc'
require 'yaml'
require 'json'

ROOT = File.expand_path(File.dirname(__FILE__))
require "#{ROOT}/service/log.rb"


VERSION = File.read("#{ROOT}/version.txt")
CONF = YAML.load(File.read("#{ROOT}/config.yml"))
DEBUG = CONF['Other']['debug']
USERS_GROUP = CONF['OpenNebula']['users-group']
TRIAL_SUSPEND_DELAY = CONF['WHMCS']['trial-suspend-delay']

USERS_VMS_SSH_PORT = CONF['OpenNebula']['users-vms-ssh-port']
DEFAULT_HOST = CONF['OpenNebula']['default-node-id']
REINSTALL_TEMPLATE_ID = CONF['OpenNebula']['reinstall-template-id']

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
CREDENTIALS = CONF['OpenNebula']['credentials']
# XML_RPC endpoint where OpenNebula is listening
ENDPOINT = CONF['OpenNebula']['endpoint']
$client = Client.new(CREDENTIALS, ENDPOINT)

require "#{ROOT}/service/time.rb"
require "#{ROOT}/service/handlers/thread_lock_handler.rb"
require "#{ROOT}/service/on_helper.rb"
require "#{ROOT}/service/ON_API/main.rb"
require "#{ROOT}/service/handlers/WHMCS.rb"

STARTUP_TIME = Time.now().to_i

LOG "", "", false
LOG("       ###########################################################", "", false)
LOG("       ##                                                       ##", "", false)
LOG "       ##    WHMCS -> OpenNebula Connector v#{VERSION.chomp}#{" " if VERSION.split(' ').last == 'stable'}     ##", "", false
LOG("       ##                                                       ##", "", false)
LOG("       ###########################################################", "", false)
LOG "", "", false

at_exit do
    LOG("Server was stoppped. Uptime: #{fmt_time(Time.now.to_i - STARTUP_TIME)}")
    LOG "", "", false
    LOG("       +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", "", false)
end

CONF['Include'].each do | lib |
    CONF.merge!(YAML.load(File.read("#{ROOT}/lib/#{lib}/config.yml"))) if File.exist?("#{ROOT}/lib/#{lib}/config.yml")
    require "#{ROOT}/lib/#{lib}/main.rb"
end if CONF['Include'].class == Array

LOG "Initializing JSON-RPC Server..."
WHMCS = WHMHandler.new($client) # Создание экземпляра хэндлер-сервера
server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:#{CONF['WHMCS']['listen-port']}") # Создание экземпляра сервера
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
