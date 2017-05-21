require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.70.215:8080")
ip, vmid, userid = client.NewAccount("23411231", "kraken@support.by", "Nhb500Gznmcjn", "debian8", 1, 1, 1024, 8192)

puts("IP: #{ip}")
puts("VMID: #{vmid}")
puts("UserID: #{userid}")