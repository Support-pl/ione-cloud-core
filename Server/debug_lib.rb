require 'yaml'
ROOT = File.expand_path(File.dirname(__FILE__))
require "#{ROOT}/service/log.rb"
`echo > #{ROOT}/log/errors.txt`
`echo > #{ROOT}/log/activities.log` if File.read("#{ROOT}/log/activities.log").split("\n").size >= 1000

CONF = YAML.load(File.read("#{ROOT}/config.yml"))
DEBUG = CONF['Other']['debug']
USERS_GROUP = CONF['OpenNebula']['users-group']
TRIAL_SUSPEND_DELAY = CONF['WHMCS']['trial-suspend-delay']
if ANSIBLE_INCLUDED = CONF['AnsibleServer']['active'] then
    ANSIBLE_HOST = CONF['AnsibleServer']['host']
    ANSIBLE_HOST_PORT = CONF['AnsibleServer']['port']
    ANSIBLE_HOST_USER = CONF['AnsibleServer']['user']
    ANSIBLE_HOST_PASSWORD = CONF['AnsibleServer']['password']
    require "#{CONF['AnsibleServer']['data-getters-url']}"
end

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