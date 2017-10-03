require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

indata = {
    'login' => 'vnc_test',
    'password' => 'Jago322==',
    'passwd' => 'Jago644==++',
    'templateid' => 16,
    'groupid' => 103,
    'release' => false,
    'trial' => false,
    'ansible' => false,
    'ansible-service' => nil,#ARGV[0],
}

hash = client.NewAccount(indata)
puts hash.inspect