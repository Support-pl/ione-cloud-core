STARTUP_TIME = Time.now().to_i

require 'zmqjsonrpc'
require 'yaml'
require 'json'

puts 'Getting path to the server'
ROOT = File.expand_path(File.dirname(__FILE__))
puts 'Including log-library'
require "#{ROOT}/service/log.rb"

puts 'Checking service version'
VERSION = File.read("#{ROOT}/meta/version.txt")

puts 'Parsing config file'
CONF = YAML.load(File.read("#{ROOT}/config.yml"))
DEBUG = CONF['Other']['debug']
USERS_GROUP = CONF['OpenNebula']['users-group']
TRIAL_SUSPEND_DELAY = CONF['WHMCS']['trial-suspend-delay']

USERS_VMS_SSH_PORT = CONF['OpenNebula']['users-vms-ssh-port']
DEFAULT_HOST = CONF['OpenNebula']['default-node-id']
REINSTALL_TEMPLATE_ID = CONF['OpenNebula']['reinstall-template-id']

puts 'Setting up Enviroment(OpenNebula API)'
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

puts "Including time-lib"
require "#{ROOT}/service/time.rb"
puts "Including thread-handler lib \t\t[!!!]"
require "#{ROOT}/service/handlers/thread_lock_handler.rb"
puts 'Including on_helper funcs'
require "#{ROOT}/service/on_helper.rb"
puts 'Including API funcs'
require "#{ROOT}/service/ON_API/main.rb"
puts 'Including service logic funcs'
require "#{ROOT}/service/handlers/WHMCS.rb"
puts 'Starting watchdog service'
require "#{ROOT}/service/handlers/watchdog.rb"

LOG "", "", false
LOG("       ###########################################################", "", false)
LOG("       ##                                                       ##", "", false)
LOG "       ##    WHMCS -> OpenNebula Connector v#{VERSION.chomp}#{" " if VERSION.split(' ').last == 'stable'}     ##", "", false
LOG("       ##                                                       ##", "", false)
LOG("       ###########################################################", "", false)
LOG "", "", false

puts 'Generating "at_exit" directive'
at_exit do
    LOG("Server was stoppped. Uptime: #{fmt_time(Time.now.to_i - STARTUP_TIME)}")
    LOG "", "", false
    LOG("       +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", "", false)
end

puts 'Including User-libs' if CONF['Include'].class == Array
CONF['Include'].each do | lib |
    CONF.merge!(YAML.load(File.read("#{ROOT}/lib/#{lib}/config.yml"))) if File.exist?("#{ROOT}/lib/#{lib}/config.yml")
    require "#{ROOT}/lib/#{lib}/main.rb"
end if CONF['Include'].class == Array

LOG "Initializing JSON-RPC Server..."
puts 'Initializing JSON_RPC server and logic handler'
server = ZmqJsonRpc::Server.new(IONe.new($client), "tcp://*:#{CONF['WHMCS']['listen-port']}") # Создание экземпляра сервера
LOG "Server initialized"

# if ARGV[0] == "test" then
#     thread = Thread.new {
#         test_server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:8008")
#         test_server.server_loop
#     }
#     sleep(30)
#     thread.exit
# end

puts 'Starting up server'
server.server_loop # Запуск сервера