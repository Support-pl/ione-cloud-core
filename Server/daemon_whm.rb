require 'daemons'

at_exit do
 
    case ARGV[0]
 
        when "start"
 
            `sh /scripts/server/daemon_utils/startmsg`
 
        when "restart"
 
            `sh /scripts/server/daemon_utils/restartmsg`
 
        when "stop"
 
            `sh /scripts/server/daemon_utils/stopmsg`
 
    end
 
end
 

 
Daemons.run('whmconnect.rb') do
 
    loop do
 
        sleep(10)
 
    end
 
end