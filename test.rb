require 'net/ssh'
require 'yaml'
require 'pry'
require '/scripts/server/service/ansible/getters.rb'

service = 'vesta'
params = {'serviceid' => 7422, 'passwd' => 'Nhb500Gznmcjn'}

Net::SSH.start('185.66.69.101', 'root', :password => 'So8ghgOdQFpcecE', :port => 52222) do | host |
    playbook = host.exec!("cat /etc/ansible/#{service}/clients/#{service}_pattern.yml")
    playbook = YAML.load(playbook)
    getter = AnsibleDataGetter.new
    binding.pry
    playbook[0]['vars'].each_key { | key | puts playbook[0]['vars'][key] = getter.send(key, params) }
    playbook = YAML.dump playbook   
    host.exec!("echo '#{playbook}' > /etc/ansible/#{service}/clients/#{service}.yml")
    # host.exec!("ansible-playbook /etc/ansible/#{service}/clients/#{service}.yml")
end