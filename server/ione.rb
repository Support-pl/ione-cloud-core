require 'zmqjsonrpc'
require 'yaml'
require 'json'
require 'ipaddr'
require 'sequel'
require 'logger'

STARTUP_TIME = Time.now().to_i # IONe server start time

puts 'Getting path to the server'
ROOT = ENV['IONEROOT'] # IONe root path
LOG_ROOT = ENV['IONELOGROOT'] # IONe logs path

if ROOT.nil? || LOG_ROOT.nil? then
    `echo "Set ENV variables $IONEROOT and $IONELOGROOT at .bashrc and systemd!"`
    raise "ENV NOT SET"
end

puts 'Parsing config file'
CONF = YAML.load_file("#{ROOT}/config.yml") # IONe configuration constants

puts 'Including log-library'
require "#{ROOT}/service/log.rb"
include IONeLoggerKit

puts 'Checking service version'
VERSION = File.read("#{ROOT}/meta/version.txt") # IONe version
DEBUG = CONF['Other']['debug'] # IONe debug level
USERS_GROUP = CONF['OpenNebula']['users-group'] # OpenNebula users group
TRIAL_SUSPEND_DELAY = CONF['Server']['trial-suspend-delay'] # Trial VMs suspend delay

USERS_VMS_SSH_PORT = CONF['OpenNebula']['users-vms-ssh-port'] # Default SSH port at OpenNebula Virtual Machines 
$default_host = CONF['OpenNebula']['default-node-id'] # Default host to deploy

puts 'Setting up Environment(OpenNebula API)'
###########################################
# Setting up Environment                   #
###########################################
ONE_LOCATION=ENV["ONE_LOCATION"] # OpenNebula location
if !ONE_LOCATION
    LOG_LOCATION = "/var/log/one"
    VAR_LOCATION = "/var/lib/one"
    ETC_LOCATION = "/etc/one"
    SHARE_LOCATION = "/usr/share/one"
    RUBY_LIB_LOCATION = "/usr/lib/one/ruby"
else
    VAR_LOCATION = ONE_LOCATION + "/var"
    LOG_LOCATION = ONE_LOCATION + "/var"
    ETC_LOCATION = ONE_LOCATION + "/etc"
    SHARE_LOCATION = ONE_LOCATION + "/share"
    RUBY_LIB_LOCATION = ONE_LOCATION+"/lib/ruby"
end

SUNSTONE_AUTH             = VAR_LOCATION + "/.one/sunstone_auth"
SUNSTONE_LOG              = LOG_LOCATION + "/sunstone.log"
CONFIGURATION_FILE        = ETC_LOCATION + "/sunstone-server.conf"

PLUGIN_CONFIGURATION_FILE = ETC_LOCATION + "/sunstone-plugins.yaml"
LOGOS_CONFIGURATION_FILE  = ETC_LOCATION + "/sunstone-logos.yaml"

SUNSTONE_ROOT_DIR         = File.dirname(__FILE__)

$: << RUBY_LIB_LOCATION
$: << RUBY_LIB_LOCATION+'/cloud'
$: << SUNSTONE_ROOT_DIR
$: << SUNSTONE_ROOT_DIR+'/models'

require "opennebula"
include OpenNebula
###########################################
# OpenNebula credentials
CREDENTIALS = CONF['OpenNebula']['credentials']
# XML_RPC endpoint where OpenNebula is listening
ENDPOINT = CONF['OpenNebula']['endpoint']
$client = Client.new(CREDENTIALS, ENDPOINT) # oneadmin auth-client

require 'cloud/CloudAuth'

ENV["ONE_CIPHER_AUTH"] = SUNSTONE_AUTH
$conf = YAML.load_file(CONFIGURATION_FILE)
$cloud_auth = CloudAuth.new($conf)
require CONF['DataBase']['adapter']
$db = Sequel.connect({
        adapter: CONF['DataBase']['adapter'].to_sym,
        user: CONF['DataBase']['user'], password: CONF['DataBase']['pass'],
        database: CONF['DataBase']['database'], host: CONF['DataBase']['host']  })

puts 'Including on_helper funcs'
require "#{ROOT}/service/on_helper.rb"
include ONeHelper
puts 'Including Deferable module'
require "#{ROOT}/service/defer.rb"

LOG(
"\n" +
"       ################################################################\n".light_green.bold +
"       ##                                                            ##\n".light_green.bold +
"       ##".light_green.bold + "       " + "I".red.bold + "ntegrated " + "O".red.bold + "pen" + "Ne".red.bold + "bula Cloud  ".light_cyan +
                                    "v#{VERSION.chomp}".cyan.underline + "#{" " if VERSION.split(' ').last == 'stable'}        " + "##\n".light_green.bold +
"       ##                                                            ##\n".light_green.bold +
"       ################################################################\n".light_green.bold +
"\n", 'none', false
)


puts 'Generating "at_exit" directive'
at_exit do
    begin
        LOG_COLOR("Server was stopped. Uptime: #{fmt_time(Time.now.to_i - STARTUP_TIME)}", "")
        LOG "", "", false
        LOG("       ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", "", false)
    rescue => e
        LOG_DEBUG e.message
    end
end

# Main App class. All methods, which must be available as JSON-RPC methods, should be defined in this class
class IONe
    include Deferable
    # IONe initializer, stores auth-client and version
    # @param [OpenNebula::Client] client 
    def initialize(client, db)
        @client = client
        @db = db
        @version = VERSION
    end
end

puts 'Including Libs'
LOG_COLOR 'Including Libs:', 'none', 'green', 'bold'
begin
    CONF['Include'].each do | lib |
        puts "\tIncluding #{lib}"    
        begin
            require "#{ROOT}/lib/#{lib}/main.rb"
            LOG_COLOR "\t - #{lib} -- included", 'none', 'green', 'itself'
        rescue => e
            LOG_COLOR "Library \"#{lib}\" was not included | Error: #{e.message}", 'LibraryController'
            puts "Library \"#{lib}\" was not included | Error: #{e.message}"
        end
    end if CONF['Include'].class == Array
rescue => e
    LOG_ERROR "LibraryController fatal error | #{e}", 'LibraryController', 'red', 'underline'
    puts "\tLibraryController fatal error | #{e}"
end

puts 'Including Modules'
LOG_COLOR 'Including Modules:', 'none', 'green', 'bold'
begin
    CONF['Modules'].each do | mod |
        puts "\tIncluding #{mod}"    
        begin
            CONF.merge!(YAML.load(File.read("#{ROOT}/modules/#{mod}/config.yml"))) if File.exist?("#{ROOT}/modules/#{mod}/config.yml")
            require "#{ROOT}/modules/#{mod}/main.rb"
            LOG_COLOR "\t - #{mod} -- included", 'none', 'green', 'itself'
        rescue => e
            LOG_COLOR "Module \"#{mod}\" was not included | Error: #{e.message}", 'ModuleController'
            puts "Module \"#{mod}\" was not included | Error: #{e.message}"
        end
    end if CONF['Modules'].class == Array
rescue => e
    LOG_ERROR "ModuleController fatal error | #{e}", 'ModuleController', 'red', 'underline'
    puts "\tModuleController fatal error | #{e}"
end

puts 'Including Scripts'
LOG_COLOR 'Starting scripts:', 'none', 'green', 'bold'
begin
    CONF['Scripts'].each do | script |
        puts "\tIncluding #{script}"
        begin
            Thread.new do
                require "#{ROOT}/scripts/#{script}/main.rb"
            end
                LOG_COLOR "\t - #{script} -- initialized", 'none', 'green', 'itself'
            rescue => e
                LOG_COLOR "Script \"#{script}\" was not started | Error: #{e.message}", 'ScriptController', 'green', 'itself'
                puts "\tScript \"#{script}\" was not started | Error: #{e.message}"
        end
    end if CONF['Scripts'].class == Array
rescue => e
    LOG_ERROR "ScriptsController fatal error | #{e}", 'ScriptController', 'red', 'underline'
    puts "ScriptsController fatal error | #{e}"
end

puts 'Making IONe methods deferable'
class IONe
    self.instance_methods(false).each do | method |
        deferable method
    end
end

$methods = IONe.instance_methods(false).map { | method | method.to_s }

LOG "Initializing JSON-RPC Server..."
puts 'Initializing JSON_RPC server and logic handler'
server = ZmqJsonRpc::Server.new(IONe.new($client, $db), "tcp://*:#{CONF['Server']['listen-port']}", Logger.new('/var/log/ione/rpc.log'))
LOG_COLOR "Server initialized", 'none', 'green'

# Signal.trap('CLD') do
#   LOG 'Trying to force stop Sinatra', 'SignalHandler'
# end

puts 'Pre-init job ended, starting up server'
server.server_loop # Server start
