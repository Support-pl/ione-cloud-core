require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

indata = {
    'login' => 'ansible_test',
    'password' => 'Jago322==',
    'passwd' => 'Jago644==++',
    'templateid' => 18,
    'groupid' => 103,
    'release' => true,
    'trial' => false,
    'ansible' => true,
    'ansible-service' => 'vesta',#ARGV[0],
}

hash = client.NewAccount(indata)
puts hash.inspect