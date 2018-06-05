require 'net/http'
require 'json'

def call(params)
    params.merge!(username: 'hell_api', password: '3924105f27ca00fd90a08aadddfb65e9', responsetype: 'json')
    return JSON.parse Net::HTTP.post_form(URI.parse('https://my.support.by/includes/api.php'), params).body
end

def GetWHMCSData(login)
    clientid = call({'action' => 'GetClientsProducts', 'serviceid' => login.split('_')[1].to_i})['products']['product'][0]['clientid']    
    # return call({'action' => 'GetClientsDetails', 'clientid' => clientid})
    return { 'email' => call({'action' => 'GetClientsDetails', 'clientid' => clientid})['email'] }
end

# puts call({"action" => 'GetClientsProducts', 'serviceid' => ARGV[0].split('_')[1].to_i}).inspect

puts GetWHMCSData(ARGV[0]).inspect
# clientid = JSON.parse(answer.body)['products']['product'][0]['clientid']

# answer = whm_api({'action' => 'GetInvoices', 'userid' => clientid})

# JSON.parse(answer.body)['invoices']['invoice'].each do | item |
#     puts "#{item['status']} -- #{item['date']} -- #{item['datepaid']}}"
# end