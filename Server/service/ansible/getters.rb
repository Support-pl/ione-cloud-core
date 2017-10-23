def whm_call(params)
    params.merge!(username: CONF['WHMCS']['username'], password: CONF['WHMCS']['password'], responsetype: 'json')
    return JSON.parse Net::HTTP.post_form(URI.parse(CONF['WHMCS']['uri']), params).body
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