require 'json'

$data = JSON.parse(File.read("#{ROOT}/lib/stat/data.json"))

at_exit do
    `echo > #{ROOT}/lib/stat/data.json`
    File.open("#{ROOT}/lib/stat/data.json", 'w') { |file| file.write(JSON.pretty_generate($data)) }    
end

def LOG_STAT(method, time)
    $data[method] = {} if $data[method].nil?
    $data[method]['calls'] = [] if $data[method]['calls'].nil?
    $data[method]['counter'] = 0 if $data[method]['counter'].nil?
    $data[method]['counter'] += 1
    $data[method]['calls'] << time
end

class WHMHandler
    def GetStatistics(params = {})
        return JSON.pretty_generate($data) if params['method'].nil? && params['json'] == true
        return $data if params['method'].nil?
        begin
            return JSON.pretty_generate($data[params['method']]) if params['json'] == true
            return $data[params['method']]
        rescue => e
            return e.message
        end
    end
end