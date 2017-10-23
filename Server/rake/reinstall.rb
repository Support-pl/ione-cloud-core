require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

args = {
    'vmid' => 598,
    'userid' => 449,
    'login' => 'user_7447',
    'passwd' => 'CGoFBsZ,,a1OeaLN',
    'templateid' => 18,
    'release' => false
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