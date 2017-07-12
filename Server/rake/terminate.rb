require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

ID = ARGV[0].to_i
puts "Deleting VM n.#{ID}"

client.Terminate(ID)