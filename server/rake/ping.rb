require 'net/telnet'
t = Time.now.to_i
begin
    host = Net::Telnet::new("Host" => '185.66.68.20', 'Timeout' => 20, "Port" => 52222)
rescue => e
    puts e.message
end
puts Time.now.to_i - t
puts host.inspect