require 'zmqjsonrpc'
client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")
ARGV = [] if ARGV.nil?
puts client.GetStatistics(json: ARGV.include?('--json'), method: (ARGV.index '-m').nil? ? nil : ARGV[ARGV.index('-m') + 1])