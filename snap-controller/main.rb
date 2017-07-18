require "rubygems"
require "json"

db_hash = JSON.parse(File.read('snap-controller.json'))

puts db_hash['host']
puts db_hash['user']
puts db_hash['pass']
puts db_hash['name']
