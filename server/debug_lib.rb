require 'zmqjsonrpc'
require 'yaml'
require 'json'
require 'ipaddr'

STARTUP_TIME = Time.now().to_i # IONe server start time

puts 'Getting path to the server'
ROOT = ENV['IONEROOT'] # IONe root path
LOG_ROOT = ENV['IONELOGROOT'] # IONe logs path

if ROOT.nil? || LOG_ROOT.nil? then
    `echo "Set ENV variables $IONEROOT and $IONELOGROOT at .bashrc and systemd!"`
    raise "ENV NOT SET"
end

puts 'Parsing config file'
CONF = YAML.load(File.read("#{ROOT}/config.yml")) # IONe configuration constants
CONF['Other']['key'] = true

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
    RUBY_LIB_LOCATION="/usr/lib/one/ruby" # OpenNebula gem location
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
$client = Client.new(CREDENTIALS, ENDPOINT) # oneadmin auth-client

puts 'Including on_helper funcs'
require "#{ROOT}/service/on_helper.rb"
include ONeHelper
puts 'Including Deferable module'
require "#{ROOT}/service/defer.rb"
# Main App class. All methods, which must be available as JSON-RPC methods, should be defined in this class
class IONe
    include Deferable
    # IONe initializer, stores auth-client and version
    # @param [OpenNebula::Client] client 
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
            puts "Library \"#{lib}\" was not included | Error: #{e.message}"
        end
    end if CONF['Include'].class == Array
rescue => e
    puts "\tLibraryController fatal error | #{e}"
end

puts 'Including Modules'
begin
    CONF['Other']['debug-modules'].each do | mod |
        puts "\tIncluding #{mod}"    
        begin
            CONF.merge!(YAML.load(File.read("#{ROOT}/modules/#{mod}/config.yml"))) if File.exist?("#{ROOT}/modules/#{mod}/config.yml")
            require "#{ROOT}/modules/#{mod}/main.rb"
        rescue => e
            puts "Module \"#{mod}\" was not included | Error: #{e.message}"
        end
    end if CONF['Modules'].class == Array
rescue => e
    puts "\tModuleController fatal error | #{e}"
end

puts 'Making IONe methods deferable'
class IONe
    self.instance_methods(false).each do | method |
        deferable method
    end
end

$methods = IONe.instance_methods(false).map { | method | method.to_s }