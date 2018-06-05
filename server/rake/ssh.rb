require 'net/ssh'
require 'yaml'
require 'pry'

service = ARGV[0]
ip = '185.66.68.14'
port = '52222'
params = { 'email' => 'nik.ivanovskij@gmail.com', 'password' => 'Nhb500Gznmcjn' }
default = { 'email' => 'example@example.org', 'password' => 'secret'}
whmcs_data = { 'email' => 'example@example.org', 'password' => 'secret' }
ANSIBLE_DEFAULT_DATA = { 'email' => 'example@example.org', 'password' => 'secret' }
Net::SSH.start('185.66.69.101', 'root', :password => 'So8ghgOdQFpcecE', :port => 52222) do | host |
    playbook = host.exec!("cat /etc/ansible/#{service}/clients/#{service}_pattern.yml") # Получение содержимого шаблонного файла playbook
    YAML.load(playbook)[0]['vars'].keys.each do | var | # Запись пользовательских данных в плейбук
        playbook.gsub!(ANSIBLE_DEFAULT_DATA[var], whmcs_data[var])
    end if !YAML.load(playbook)[0]['vars'].nil?
    puts YAML.load(playbook)[0]
end