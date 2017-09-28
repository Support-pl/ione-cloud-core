require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

client.suspend_test({'userid' => 393, 'vmid' => 347})