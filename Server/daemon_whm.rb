require 'daemons'
ROOT = File.expand_path(File.dirname(__FILE__))
Daemons.run("#{ROOT}/whmconnect.rb")