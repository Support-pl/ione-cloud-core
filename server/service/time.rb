def time(method = 'none')
    return Time.at(Time.now + TRIAL_SUSPEND_DELAY).ctime if method == 'TrialController'
    return Time.now.ctime
end