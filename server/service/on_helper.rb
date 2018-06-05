def get_pool_element(type, id, client)
    return type.new(type.build_xml(id), client)
end