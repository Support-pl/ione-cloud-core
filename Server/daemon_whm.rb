require 'daemons'
require './service/log.rb'

Daemons.run('whmconnect.rb') do
 
    loop do
 
        LOG "'I'm working", "Daemon"
        sleep(10)
 
    end
 
end

case ARGV[0]
    when "start"
        `ruby /scripts/server/daemon_utils/startmsg`
        puts "whmconnect.rb started with pid#{File.read('./whmconnect.rb.pid')}"
    when "restart"
        `ruby /scripts/server/daemon_utils/restartmsg`
    when "stop"
        `ruby /scripts/server/daemon_utils/stopmsg`
end