require 'zmqjsonrpc'
# require 'passgen'
require 'yaml'
`echo > log/errors.txt`

ROOT = File.expand_path(File.dirname(__FILE__))
CONF = YAML.load(File.read("#{ROOT}/config.yml"))
USERS_GROUP = CONF['OpenNebula']['users-group']
TRIAL_SUSPEND_DELAY = CONF['WHMCS']['trial-suspend-delay']
ANSIBLE_HOST = CONF['AnsibleServer']['ip']
ANSIBLE_HOST_PORT = CONF['AnsibleServer']['port']
ANSIBLE_HOST_USER = CONF['AnsibleServer']['user']
ANSIBLE_HOST_PASSWORD = CONF['AnsibleServer']['password']

USERS_VMS_SSH_PORT = CONF['OpenNebula']['users-vms-ssh-port']

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
client = Client.new(CREDENTIALS, ENDPOINT)

require "#{ROOT}/service/time.rb"
require "#{ROOT}/service/log.rb"
require "#{ROOT}/service/ON_API/main.rb"
require "#{ROOT}/service/handlers/WHMCS.rb"
require "#{ROOT}/service/handlers/WHMCS_api.rb"


at_exit do
    LOG("Server was stoppped")
end

LOG("-----------------------------------------------------------", "", false)
LOG "Initializing JSON-RPC Server..."
WHMCS = WHMHandler.new(client) # Создание экземпляра хэндлер-сервера
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
