require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")
indata = {
    'login' => 'user_7655',
    'password' => 'eiOpz+Y>aL=Nd8Xa',
    'passwd' => 'QWN4STtrJZcu+Zvt',
    'templateid' => 16,
    'groupid' => 103,
    'release' => true,
    'trial' => false,
    'ansible' => true,
    'ansible-service' => 'vesta',#ARGV[0],
    'serviceid' => 7655,
    'ip' => '185.66.68.4'
}

# {"userid"=>476, "vmid"=>656, "ip"=>"185.66.68.37"}

client.AnsibleController(indata) 