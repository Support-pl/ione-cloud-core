require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

result = client.unsuspend_test({'vmid' => 347, 'login' => 'suspend_test', 'password' => 'Jago644==++', 'groupid' => 103})

puts result['userid']
`echo #{result['xml']} > /scripts/ss.txt`