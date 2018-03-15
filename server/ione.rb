STARTUP_TIME = Time.now().to_i

require 'zmqjsonrpc'
require 'yaml'
require 'json'

puts 'Getting path to the server'
ROOT = ENV['IONEROOT']
LOG_ROOT = ENV['IONELOGROOT']

if ROOT.nil? || LOG_ROOT.nil? then
    `echo "Set ENV variables $IONEROOT and $IONELOGROOT at .bashrc and systemd!"`
    raise "ENV NOT SET"
end

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
puts 'Including on_helper funcs'
require "#{ROOT}/service/on_helper.rb"
puts 'Including API funcs'
require "#{ROOT}/service/ON_API/main.rb"
puts 'Including service logic funcs'
require "#{ROOT}/service/handlers/WHMCS.rb"

LOG "", "", false
LOG("       ################################################################", "", false)
LOG("       ##                                                            ##", "", false)
LOG "       ##    Integrated OpenNebula Cloud Server v#{VERSION.chomp}#{" " if VERSION.split(' ').last == 'stable'}     ##", "", false
LOG("       ##                                                            ##", "", false)
LOG("       ################################################################", "", false)
LOG "", "", false

puts 'Generating "at_exit" directive'
at_exit do
    LOG("Server was stoppped. Uptime: #{fmt_time(Time.now.to_i - STARTUP_TIME)}")
    LOG "", "", false
    LOG("       ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", "", false)
end

# Basic App class definition  
class IONe
    def initialize(client)
        @client = client
        @version = VERSION
    end
end

puts 'Including Libs'
begin
    CONF['Include'].each do | lib |
        puts "\tIncluding #{lib}"    
        begin
            require "#{ROOT}/lib/#{lib}/main.rb"
        rescue => e
            LOG "Library \"#{lib}\" was not included | Error: #{e.message}", 'LibraryController'
            puts "Library \"#{lib}\" was not included | Error: #{e.message}"
        end
    end if CONF['Include'].class == Array
rescue => e
    LOG "LibraryController fatal error | #{e}", 'LibraryController'
    puts "\tLibraryController fatal error | #{e}"
end

puts 'Including Modules'
begin
    CONF['Modules'].each do | mod |
        puts "\tIncluding #{mod}"    
        begin
            CONF.merge!(YAML.load(File.read("#{ROOT}/modules/#{mod}/config.yml"))) if File.exist?("#{ROOT}/modules/#{mod}/config.yml")
            require "#{ROOT}/modules/#{mod}/main.rb"
        rescue => e
            LOG "Module \"#{mod}\" was not included | Error: #{e.message}", 'ModuleController'
            puts "Module \"#{mod}\" was not included | Error: #{e.message}"
        end
    end if CONF['Modules'].class == Array
rescue => e
    LOG "ModuleController fatal error | #{e}", 'ModuleController'
    puts "\tModuleController fatal error | #{e}"
end

puts 'Including Scripts'
begin
    CONF['Scripts'].each do | script |
        puts "\tIncluding #{script}"
        begin
            Thread.new do
                require "#{ROOT}/scripts/#{script}/main.rb"
            end
        rescue => e
            LOG "Script \"#{script}\" was not included | Error: #{e.message}", 'ScriptController'
            puts "\tScript \"#{script}\" was not included | Error: #{e.message}"
        end
    end if CONF['Scripts'].class == Array
rescue => e
    LOG "ScriptsController fatal error | #{e}", 'ScriptController'
    puts "ScriptsController fatal error | #{e}"
end

LOG "Initializing JSON-RPC Server..."
puts 'Initializing JSON_RPC server and logic handler'
server = ZmqJsonRpc::Server.new(IONe.new($client), "tcp://*:#{CONF['Server']['listen-port']}") # Создание экземпляра сервера
LOG "Server initialized"

# if ARGV[0] == "test" then
#     thread = Thread.new {
#         test_server = ZmqJsonRpc::Server.new(WHMCS, "tcp://*:8008")
#         test_server.server_loop
#     }
#     sleep(30)
#     thread.exit
# end

puts 'Pre-init job ended, starting up server'
server.server_loop # Запуск сервера