require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

puts("login")
login = gets.to_s
begin
    ip, vmid, userid, errors = client.NewAccount("23411231", login.chomp!, "Nhb500Gznmcjn", 1, 2, 1, 1024, 8192) # (BillingID, ONLogin, Pass, VMQuota, OS, CPU, RAM, Disk)
rescue => e
    puts e.message
end


puts("IP: #{ip}")
puts("VMID: #{vmid}")
puts("UserID: #{userid}")
puts("Errors:")
errors.map{ |elem| puts(elem)}