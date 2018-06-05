require 'net/http'
require 'json'

def call(params)
    params.merge!(username: CONF['WHMCS']['username'], password: CONF['WHMCS']['password'], responsetype: 'json')
    return JSON.parse Net::HTTP.post_form(URI.parse(CONF['WHMCS']['uri']), params).body
end

def GetWHMCSData(login, args)
    clientid = call({'action' => 'GetClientsProducts', 'serviceid' => login.split('_')[1].to_i})['products']['product'][0]['clientid']    
    return { 'email' => call({'action' => 'GetClientsDetails', 'clientid' => clientid})['email'], 'password' => args['passwd'] }
end

ANSIBLE_DEFAULT_DATA = CONF['AnsibleServer']['default-data']

# ANSIBLE_DEFAULT_DATA = { 'email' => 'example@example.org', 'password' => 'secret' }