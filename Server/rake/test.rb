require 'rubygems'
require 'zmqjsonrpc'
require 'nori'
require 'pry'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

one, two = client.test

binding.pry