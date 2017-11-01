def whm_call(params)
    params.merge!(username: CONF['WHMCS']['username'], password: CONF['WHMCS']['password'], responsetype: 'json')
    return JSON.parse Net::HTTP.post_form(URI.parse(CONF['WHMCS']['uri']), params).body
end

class WHM
    def LogtoTicket(subject, message, method, priority = 'Medium')
        # return {action: 'OpenTicket', deptid: 3,
        # subject: subject, priority: priority, admin: true,
        # name: method, email: "#{method.chomp.downcase}@cloud.support.by", message: message}
        return whm_call({
            action: 'OpenTicket', deptid: 3,
            subject: subject, message: message,
            priority: priority, admin: true, name: method, email: "#{method.chomp.downcase}@cloud.support.by"
        })['result']
    end
end

class AnsibleDataGetter

    # Put your data get methods here

    def email(params)
        return whm_call({
            'action' => 'GetClientsDetails',
            'clientid' => whm_call({
                'action' => 'GetClientsProducts',
                'serviceid' => params['serviceid']
                })['products']['product'][0]['clientid']
        })['email']
    end

    def password(params)
        return params['passwd']
    end

end