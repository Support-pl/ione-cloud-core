require "nokogiri"
require 'rubygems'
require 'zmqjsonrpc'

`sh query.sh`


def time_limit(time)
    return (Time.now().to_i - time.to_i) / 60.0 / 60.0 / 24.0 >= 1
end

file = File.read('tmp/result.txt')

vms = file.split("</VM>").each do | item |
    Nokogiri::XML(item)
end

found = ""
if ARGV[0] == nil then
    found = "false"
elsif ARGV[0] == "false" then
    Kernel.abort
elsif ARGV[0] == "true" then
    found = "false"
end

vms.each do | xml |
    xml = Nokogiri::XML(xml)
    time = xml.xpath("//SNAPSHOT//TIME").first
    if time == nil then
        break
    end
    vmid = xml.xpath("//ID").first.content.to_i
    snapid = xml.xpath("//SNAPSHOT//SNAPSHOT_ID").first.content.to_i
    if time_limit(time.content.to_i) then
        puts "Snapshot of VM#{vmid} number #{snapid} should be deleted - it was created more than #{((Time.now.to_i - time.content.to_i) / 60.0 / 60.0).round 0} hours ago."
    else
        puts "Snapshot of VM#{vmid} number #{snapid} was created #{((Time.now.to_i - time.content.to_i) / 60.0 / 60.0).round 2} hours ago."        
    end
end