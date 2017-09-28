require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8088")

indata = {
    'login' => 'user_7375',
    'password' => 'Jago322==',
    'passwd' => 'Jago644==++',
    'templateid' => 16,
    'groupid' => 103,
    'release' => true,
    'trial' => false,
    'ansible' => true,
    'ansible-service' => ARGV[0],
    'test' => false
}

hash = client.NewAccount(indata)
puts hash.inspect