require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")
vmid = ARGV[0]

puts "#{client.STATE_STR(vmid)} -- #{client.STATE(vmid)}"

puts "#{client.LCM_STATE_STR(vmid)} -- #{client.LCM_STATE(vmid)}"

if ARGV[1] == 'loop' then
    until client.LCM_STATE(vmid).to_i == 3 && client.STATE(vmid).to_i == 3 do
        puts "#{client.STATE_STR(vmid)} -- #{client.STATE(vmid)}"
        
        puts "#{client.LCM_STATE_STR(vmid)} -- #{client.LCM_STATE(vmid)}"
        sleep(10)
    end
end