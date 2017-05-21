require 'json'

def GetTemplate(os)
    json = File.read('../data/templates.json')
    templ_hash = JSON.parse(json)
    return templ_hash[os]
end