require 'time.rb'

def LOG(msg, _time = true)
    if _time then
        `echo "[ #{time()} ] #{msg}" >> #{ROOT}/log/activities.log`
    else
        `echo "#{msg}" >> #{ROOT}/log/activities.log`
    end
end