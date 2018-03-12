STARTUP_TIME = Time.now().to_i

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

puts 'Including Libs'
begin
    CONF['Include'].each do | lib |
        puts "\tIncluding #{lib}"    
        begin
            require "#{ROOT}/lib/#{lib}/main.rb"
        rescue => e
            puts "Library \"#{lib}\" was not included"
        end
    end if CONF['Include'].class == Array
rescue => e
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
            puts "Module \"#{mod}\" was not included"
        end
    end if CONF['Modules'].class == Array
rescue => e
    puts "\tModuleController fatal error | #{e}"
end

puts 'Including Scripts'
begin
    CONF['Scripts'].each do | script |
        puts "\tIncluding #{script}"
        begin
            # Thread.new do
                require "#{ROOT}/scripts/#{script}/main.rb"
            # end
        rescue => e
            puts "\tScript \"#{script}\" was not included"
        end
    end if CONF['Scripts'].class == Array
rescue => e
    puts "ScriptsController fatal error | #{e}"
end