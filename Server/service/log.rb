require '/scripts/server/service/time.rb'

$log = []

at_exit do
    File.open("#{ROOT}/log/old.log", 'w') { |file| file.write($log.join("\n")) }
end

def LOG(msg, method = "none", _time = true)
    case method
        when 'DEBUG'
            destination = "#{ROOT}/log/debug.log"
        when "SnapController"
            destination = "#{ROOT}/log/snapshot.log"
        else
            destination = "#{ROOT}/log/activities.log"
    end

    msg = "[ #{time(method)} ] " + msg if _time
    msg += " [ #{method} ]" if method != 'none' && method != "" && method != nil

    `echo '#{msg}' >> #{destination}`
    $log << "#{msg} | #{destination}"
    puts "Should be logged, params - #{method}, #{_time}, #{destination}:\n#{msg}" if DEBUG

    return true
end