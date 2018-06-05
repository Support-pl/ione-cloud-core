require 'rubygems'
require 'zmqjsonrpc'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8088")

args = {
    'login' => 'tesing',
    'password' => 'Jago322==',
    'passwd' => 'Jago644==++',
    'templateid' => 18,
    'groupid' => 103,
    'release' => true,
    'trial' => false,
    'ansible' => true,
    'ansible-service' => 'vesta',#ARGV[0],
    'serviceid' => 7199,
    'vmid' => 655,
    'ip' => '185.66.68.37',
    'result' => '
    PLAY [installvestaclients] *************************************************
    
    TASK [Gathering Facts] *****************************************************
    fatal: [185.66.68.254]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: ssh: connect to host 185.66.68.254 port 52222: Connection refused\r\n", "unreachable": true}
            to retry, use: —limit @/etc/ansible/vesta/clients/vesta.retry
    
    PLAY RECAP *****************************************************************
    185.66.68.254              : ok=0    changed=0    unreachable=1    failed=0'
}

puts client.test(args).inspect