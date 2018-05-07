module IONeLoggerKit
    require "#{ROOT}/service/time.rb"

    begin
        `mkdir #{LOG_ROOT}`
    rescue
    end
    `echo > #{LOG_ROOT}/errors.txt`
    `echo > #{LOG_ROOT}/sys.log` if !CONF['Other']['key']
    begin
        `echo > #{LOG_ROOT}/activities.log` if File.read("#{LOG_ROOT}/activities.log").split("\n").size >= 1000
    rescue
        `echo > #{LOG_ROOT}/activities.log`
    end

    $log = []

    at_exit do
        File.open("#{LOG_ROOT}/old.log", 'a') { |file| file.write($log.join("\n")) }
    end

    def LOG(msg, method = "none", _time = true)
        case method
        when 'DEBUG'
            destination = "#{LOG_ROOT}/debug.log"
        when "SnapController"
            destination = "#{LOG_ROOT}/snapshot.log"
        else
            destination = "#{LOG_ROOT}/activities.log"
        end
        msg = msg.to_s
        msg = "[ #{time(method)} ] " + msg if _time
        msg += " [ #{method} ]" if method != 'none' && method != "" && method != nil

        File.open(destination, 'a'){ |log| log.write msg + "\n" }
        File.open("#{LOG_ROOT}/suspend.log", 'a'){ |log| log.write msg + "\n" } if method == 'Suspend'

        $log << "#{msg} | #{destination}"
        puts "Should be logged, params - #{method}, #{_time}, #{destination}:\n#{msg}" if DEBUG
        return true
    end

    def LOG_TEST(msg, method = caller_locations(1,1)[0].label, _time = true)
        case method
        when 'DEBUG'
            destination = "#{LOG_ROOT}/debug.log"
        when "SnapController"
            destination = "#{LOG_ROOT}/snapshot.log"
        else
            destination = "#{LOG_ROOT}/activities.log"
        end
        msg = msg.to_s
        msg = "[ #{time(method)} ] " + msg if _time
        msg += " [ #{method} ]" if method != 'none' && method != "" && method != nil

        File.open(destination, 'a'){ |log| log.write msg + "\n" }
        File.open("#{LOG_ROOT}/suspend.log", 'a'){ |log| log.write msg + "\n" } if method == 'Suspend'

        $log << "#{msg} | #{destination}"
        puts "Should be logged, params - #{method}, #{_time}, #{destination}:\n#{msg}" if DEBUG
        return true
    end

    $PROC = []

    def LOG_CALL(id, called, method = caller_locations(1,1)[0].label)
        level, method = 0, method.to_s
        caller_locations.each do | loc |
            loc = loc.label
            if $methods.include? loc then
                level += 1
                next
            end
            $methods.each do | method |
                if loc.include? method then
                    level += 1 
                    break
                end
            end
        end
        if called then
            
        elsif !called then
            
        end 
        msg = "[ #{time()} ] Method #{called ? $PROC.push("#{method}:#{id}").last : $PROC.delete("#{method}:#{id}")} #{called ? 'called' : 'closed'}\n" if level < 2
        if level > 1  || !called then
            tabs = "                             "
            for i in 0..(level - 3) do
                tabs += "    "
            end
            msg = "#{tabs}|-- Method #{method.to_s}:#{id} #{called ? 'called' : 'closed'}\n"
        end

        File.open(LOG_ROOT + '/sys.log', 'a'){ |log| log.write msg }
        return true
    end

    class IONe
        # Get log from activities.log file
        # @return [String] Log
        def activity_log()
            LOG_STAT()        
            LOG "Log file content has been copied remotely", "activity_log"
            log = File.read("#{LOG_ROOT}/activities.log")
            return log
        end
        # Logs given message to activities.log
        # @param [String] msg - your message
        # @return [String] returns given message
        def log(msg)
            LOG_STAT()        
            LOG(msg, "RemoteLOG")
    	    return msg
        end
    end

    $id = 0

    def id_gen
        return ($id += 1).to_s(16)
    end
end