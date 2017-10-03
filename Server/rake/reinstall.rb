require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

args = {
    'vmid' => 537,
    'userid' => 428,
    'login' => 'reinstall_test_user',
    'passwd' => 'Nhb500Gznmcjn',
    'release' => true,
    'templateid' => 18,
}

puts client.Reinstall(args)