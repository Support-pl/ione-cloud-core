require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

client.Suspend(ARGV[0].to_i, ARGV[1].to_i)