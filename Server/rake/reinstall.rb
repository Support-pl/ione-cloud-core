require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

args = {
    'vmid' => 530,
    'userid' => 427,
    'login' => 'dev_machine_3.0',
    'passwd' => 'Y+eQ+zHZiw3bHQts',
    'templateid' => 16,
    'release' => true
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