def time(method = 'none')
    return Time.at(Time.now + TRIAL_SUSPEND_DELAY).ctime if method == 'TrialController'
    return Time.now.ctime
end

def fmt_time(sec)
    sec = sec.to_i
    return "#{sec / 3600 / 24}d:#{sec / 3600}h:#{sec / 60}m:#{sec % 60}s"
end