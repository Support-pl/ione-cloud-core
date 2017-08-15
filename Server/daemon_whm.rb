require 'daemons'

Daemons.run('whmconnect.rb') do
 
    loop do
 
        sleep(10)
 
    end
 
end

case ARGV[0]
    when "start"
        `ruby /scripts/server/daemon_utils/startmsg`
    when "restart"
        `ruby /scripts/server/daemon_utils/restartmsg`
    when "stop"
        `ruby /scripts/server/daemon_utils/stopmsg`
end