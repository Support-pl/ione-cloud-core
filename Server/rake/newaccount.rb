require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

puts("login")
login = gets.to_s.chomp
begin
    vmid, userid, ip = client.NewAccount(login, "Jago322==", 0, 112, false) # login, pass, templateid, groupid, deploy = false
rescue => e
    puts e.message
end


puts("VMID: #{vmid}")
puts("UserID: #{userid}")
puts("IP: #{ip}")