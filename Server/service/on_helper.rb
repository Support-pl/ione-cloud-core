def get_pool_element(type, id, client)
    return type.new(type.build_xml(id), client)
end

def onblock(object, id, client)
    case object
        when 'vm'
            object = VirtualMachine
        when 'temp'
            object = Template
        when 'host'
            object = Host
        when 'user'
            object = User
        else
            return 'Unknown class entered'
    end
    if block_given?
        yield get_pool_element(object, id, client)
    end
end