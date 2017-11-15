require '/scripts/server/service/time.rb'

def LOG(msg, method = "none", _time = true)
    if _time then
        `echo "[ #{time(method)} ] #{msg} [ #{method} ]" >> #{ROOT}/log/activities.log`
    elsif method == 'DEBUG' then
        `echo "#{msg}" >> #{ROOT}/log/debug.log`        
    elsif method == "" then
        `echo "#{msg}" >> #{ROOT}/log/activities.log`
    elsif _time == false then
        `echo "#{msg}  [ #{method} ]" >> #{ROOT}/log/activities.log`
    end
    return true
end