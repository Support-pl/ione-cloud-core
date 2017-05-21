require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://localhost:8080")
ip, vmid = client.NewAccount("23411231", "nick.iwanowski@support.by", "Nhb500Gznmcjn", "ubuntu-15.04", 1, 1, 1024, 8192)

puts("IP: #{ip}")
puts("VMID: #{vmid}")

result = client.Terminate("nick.iwanowski@support.by", [126])
puts(result)
result = client.Terminate("nick.iwanowski@support.by", [123, 254])
puts(result)

ip, vmid = client.AddVM(6666666, "nick.iwanowski@support.by", 2, "debian8", 2, 2048, 16384)
puts("IP: #{ip}")
puts("VMID: #{vmid}")