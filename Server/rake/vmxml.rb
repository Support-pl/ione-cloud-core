require 'rubygems'
require 'zmqjsonrpc'
require 'nokogiri'

client = ZmqJsonRpc::Client.new("tcp://185.66.68.238:8008")

xml = Nokogiri::XML(client.VM_XML(ARGV[0].to_i))

puts xml.at_xpath('//GUEST_IP').content