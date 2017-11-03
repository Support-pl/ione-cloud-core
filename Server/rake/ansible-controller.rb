require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")
indata = {
    'login' => 'user_7589',
    'password' => 'rYSPzdl7a,6dUuUu',
    'passwd' => 'rYSPzdl7a,6dUuUu',
    'templateid' => 16,
    'groupid' => 103,
    'release' => true,
    'trial' => false,
    'ansible' => true,
    'ansible-service' => 'vesta',#ARGV[0],
    'serviceid' => 7589,
    'vmid' => 688,
    'ip' => '185.66.68.18'
}

# {"userid"=>476, "vmid"=>656, "ip"=>"185.66.68.37"}

client.AnsibleController(indata) 