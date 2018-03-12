$proc = []
def kill_proc(id)
    begin
        $proc.delete id
    rescue
    end
    return nil
end
def proc_id_gen(method)
    id = "#{method.to_s}_" + Time.now.to_i.to_s(16).crypt(method.to_s)
    $proc << id
    return id
end    

def whm_call(params)
    params.merge!(username: CONF['WHMCS']['username'], password: CONF['WHMCS']['password'], responsetype: 'json')
    return JSON.parse Net::HTTP.post_form(URI.parse(CONF['WHMCS']['uri']), params).body
end

class WHM
    def LogtoTicket(params) # Логгирование в тикет WHMCS
        return whm_call({ # В случае, если в параметрах не был передан id тикета, будет создан новый
            action: 'OpenTicket', deptid: 6,
            subject: params[:subject], message: params[:message],
            priority: params[:priority].nil? ? 'Low' : params[:priority],
            admin: true, name: params[:method], email: "#{params[:method].chomp.downcase}@cloud.support.by",
        }).merge!(:part => 'new') if params[:id].nil?
        result = whm_call({
            action: 'AddTicketReply', ticketid: params[:id],
            message: params[:message], status: 'Open', adminusername: params[:method]
        })
        return result.merge!(:part => 'old') if params[:priority].nil?
        return result, whm_call({
            action: 'UpdateTicket', ticketid: params[:id],
            priority: params[:priority]
        }).merge!(:part => 'old_p')
    end
end