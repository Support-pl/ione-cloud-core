require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

args = {
    'vmid' => 656,
    'userid' => 476,
    'login' => 'testing',
    'passwd' => 'Nhb500Gznmcjn',
    'templateid' => 16,
    'release' => true,
    'ansible' => true,
    'ansible-service' => 'vesta',
    'serviceid' => 7199,
}

puts client.Reinstall(args)

# puts "==========VM-TEMPLATE=========="
# puts vm_xml#['VM']['TEMPLATE']['NIC'].inspect
# puts "==============================="
# puts "===========TEMPLATE============"
# puts temp#['VMTEMPLATE']['TEMPLATE']['NIC'].inspect
# puts "==============================="
# puts "============EDITED============="
# puts tempn.inspect
# puts "==============================="