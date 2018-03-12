require 'json'
puts 'Parsing statistics data'
$data = JSON.parse(File.read("#{ROOT}/lib/stat/data.json"))

puts 'Binding "at_exit" actions for statistics-helper'
at_exit do
    `echo > #{ROOT}/lib/stat/data.json`
    File.open("#{ROOT}/lib/stat/data.json", 'w') { |file| file.write(JSON.pretty_generate($data)) }    
end

puts 'Initializing stat-method'
def LOG_STAT(method, time)
    $data[method] = {} if $data[method].nil?
    $data[method]['calls'] = [] if $data[method]['calls'].nil?
    $data[method]['counter'] = 0 if $data[method]['counter'].nil?
    $data[method]['counter'] += 1
    $data[method]['calls'] << time
end

puts 'Extending Handler class by statistic-getter'
class IONe
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