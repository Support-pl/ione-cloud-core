require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

puts("login")
login = gets.to_s
begin
    ip, vmid, userid = client.NewAccount("tester", "Jago322==", 0, 108) # (BillingID, ONLogin, Pass, VMQuota, OS, CPU, RAM, Disk)
rescue => e
    puts e.message
end


puts("IP: #{ip}")
puts("VMID: #{vmid}")
puts("UserID: #{userid}")