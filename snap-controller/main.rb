require "nokogiri"
require 'rubygems'
require 'zmqjsonrpc'

$client = ZmqJsonRpc::Client.new("tcp://localhost:8008")
StartTime = Time.now().to_i

def time_limit(time)
    return (Time.now().to_i - time.to_i) / 60.0 / 60.0 / 24.0 >= 1
end

def SnapshotCleaner()
    `sh #{File.expand_path(File.dirname(__FILE__))}/query.sh #{File.expand_path(File.dirname(__FILE__))}`

    file = File.read("#{File.expand_path(File.dirname(__FILE__))}/tmp/result.txt")

    vms = file.split("</VM>").each do | item |
        Nokogiri::XML(item)
    end

    found = false
    vms.each do | xml |
        xml = Nokogiri::XML(xml)
        time = xml.xpath("//SNAPSHOT//TIME").first
        if time == nil then
            break
        end
        vmid = xml.xpath("//ID").first.content.to_i
        snapid = xml.xpath("//SNAPSHOT//SNAPSHOT_ID").first.content.to_i
        if time_limit(time.content.to_i) then
            puts "#{vmid} - #{snapid}"
            $client.RMSnapshot(vmid, snapid)
            found = true
        end
    end
    return found
end

while SnapshotCleaner() do
    if (Time.now().to_i - StartTime) / 60.0 > 50 then
        puts "Scripts time to life is more than 50 minutes. It will be stopped automatically!"
        Kernel.abort
    end
    puts "Sleeping..."
    sleep 300
    puts "Continue!"
end

puts "DONE!"