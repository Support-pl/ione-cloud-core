#!/usr/bin/env ruby

##############################################################################
# Environment Configuration
##############################################################################
ONE_LOCATION=ENV["ONE_LOCATION"]

if !ONE_LOCATION
    RUBY_LIB_LOCATION="/usr/lib/one/ruby"
else
    RUBY_LIB_LOCATION=ONE_LOCATION+"/lib/ruby"
end

$: << RUBY_LIB_LOCATION

##############################################################################
# Required libraries
##############################################################################
require "opennebula"

include OpenNebula

# OpenNebula credentials
CREDENTIALS = "oneadmin:Nhb500Gznmcjn"
# XML_RPC endpoint where OpenNebula is listening
ENDPOINT    = "http://localhost:2633/RPC2"

client = Client.new(CREDENTIALS, ENDPOINT)

user = User.new(User.build_xml(100), client)
user.allocate("script-tester", "iloverocknroll")
user.chgrp(157)
user.set_quota("VM=[
  CPU=\"-1\",
  MEMORY=\"-1\",
  SYSTEM_DISK_SIZE=\"6000\",
  VMS=\"-1\" ]")