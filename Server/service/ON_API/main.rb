def Connect()
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

    return client
end

def UserCreate(login, pass, quota)
    client = Connect()
    user = User.new(User.build_xml(100), client)
    user.allocate(login, pass)
    user.chgrp(157)
    user.set_quota(quota)
end