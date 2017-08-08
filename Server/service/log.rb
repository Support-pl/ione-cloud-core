require 'time.rb'

def LOG(msg, method = "none", _time = true)
    if _time then
        `echo "[ #{time()} ] #{msg} [ #{method} ]" >> #{ROOT}/log/activities.log`
    elsif method == "" then
        `echo "#{msg}" >> #{ROOT}/log/activities.log`
    elsif _time == false then
        `echo "#{msg}  [ #{method} ]" >> #{ROOT}/log/activities.log`
    end
end