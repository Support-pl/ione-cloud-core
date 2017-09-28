require "nokogiri"
require 'rubygems'
require 'zmqjsonrpc'
require 'json'
require 'nori'

LOCAL_ROOT = File.expand_path(File.dirname(__FILE__))
ROOT = LOCAL_ROOT + '/../server'
$exeptions = JSON.parse(File.read("#{LOCAL_ROOT}/config.json"))['exeptions']#.to_a
$deleted = Hash.new("DELETED_SNAPSHOTS")

require '/scripts/server/service/log.rb'

`ruby #{LOCAL_ROOT}/cron_work/monitoring.rb` if ARGV[0].nil?
LOG 'Monitoring job started', "WhmConnectCron" if ARGV[0] == 'log'

LOG "SnapshotController-job started", "SnapshotController" if ARGV[0] == 'log'
at_exit do
    if !$deleted.empty? then
        LOG "The next VM's snapshots was passed:\n                             #{$deleted.inspect}", "SnapshotController" if ARGV[0] == 'log'
    end
    LOG "SnapshotController-job ended", "SnapshotController" if ARGV[0] == 'log'
end

$client = ZmqJsonRpc::Client.new("tcp://localhost:8008")
StartTime = Time.now().to_i

def time_limit(time)
    return (Time.now().to_i - time.to_i) / 60.0 / 60.0 / 24.0 >= 1
end

def SnapshotCleaner()
    `sh #{File.expand_path(File.dirname(__FILE__))}/query.sh #{File.expand_path(File.dirname(__FILE__))}`

    file = File.read("#{LOCAL_ROOT}/tmp/result.txt")

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
        next if Nori.new.parse(xml.to_s)['VM']['STATE'].to_i == 6
        vmid = xml.xpath("//ID").first.content.to_i
        if $exeptions.include?(vmid.to_s) then
            LOG "VM#{vmid} passed, because it is in exeption list", "SnapshotController" if ARGV[0] == 'log'
            next
        end
        snapid = xml.xpath("//SNAPSHOT//SNAPSHOT_ID").first.content.to_i
        if time_limit(time.content.to_i) && $deleted[vmid.to_s] != snapid then
            $client.RMSnapshot(vmid, snapid)
            found = true
            $deleted[vmid.to_s] = snapid
        end
    end
    return found
end

while SnapshotCleaner() do
    if (Time.now().to_i - StartTime) / 60.0 > 50 then
        LOG "Scripts life-time is more than 50 minutes. It will be stopped automatically!", "SnapshotController" if ARGV[0] == 'log'
        Kernel.abort
    end
    sleep 300
end

LOG "The next VM's snapshots was passed:\n                             #{$deleted.inspect}", "SnapshotController" if ARGV[0] == 'log'