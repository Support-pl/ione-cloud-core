require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

puts "Deleting User ##{ARGV[0].to_i} and VM##{ARGV[1].to_i}"

client.Terminate(ARGV[0].to_i, ARGV[1].to_i, true)