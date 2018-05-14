# WHMCS API connection funcs module
module WHMCS
    # Calling WHMCS HTTP API
    # @param [Hash] params - Query hash
    # @example
    #       whm_call({
    #          action: 'AddTicketReply', ticketid: params[:id],
    #          message: 'Some reply', status: 'Open', adminusername: 'admin'
    #       }) => WHMCS answer
    def whm_call(params)
        params.merge!(username: CONF['WHMCS']['username'], password: CONF['WHMCS']['password'], responsetype: 'json')
        return JSON.parse Net::HTTP.post_form(URI.parse(CONF['WHMCS']['uri']), params).body
    end
    # Creating WHMCS support ticket
    # @param [Hash] params
    # @option params [Integer] :deptid Department ID to assign ticket
    # @option params [String] :subject Ticket subject
    # @option params [String] :message Message body
    # @option params [String] :priority Ticket priority (Low|High|etc)
    # @option params [String] :method Method will be used as ticket sender name
    # @option params [Integer] :id [Optional] Ticket ID to update

    def LogtoTicket(params)
        return whm_call({ # В случае, если в параметрах не был передан id тикета, будет создан новый
            action: 'OpenTicket', deptid: params[:deptid],
            subject: params[:subject], message: params[:message],
            priority: params[:priority].nil? ? 'Low' : params[:priority],
            admin: true, name: params[:method], email: "#{params[:method].chomp.downcase}@vcloud.support.by",
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