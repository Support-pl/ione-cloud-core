require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

os = gets.to_s
os.chomp

puts client.TemplateTest(os)