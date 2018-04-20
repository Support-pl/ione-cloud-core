require 'json'

# @!visibility private
WebApiEnv = Thread.new do
    require 'sinatra/base'
    class WebApi < Sinatra::Base
        configure do
            set :bind, CONF['WebApi']['bind']
            set :port, CONF['WebApi']['port']
        end

        use Rack::Auth::Basic, "Protected Area" do |username, password|
            onblock(:u, 0, OpenNebula::Client.new("#{username}:#{password}", ENDPOINT)).info!.nil?
        end

        def responce(msg, meth = 'none')
            JSON.pretty_generate({:responce => msg, :methods => meth})
        end

        def responce_html_table(data = [])
            Nokogiri::HTML::Builder.new do | doc |
                doc.html {
                    doc.head {
                        doc.style('TD, TH { border: 1px solid black; }')
                        doc.style('TH { background: #f9ff00; }')
                        doc.style('TABLE { border-collapse: collapse; }')
                    }
                    doc.body {
                        doc.table(:style => 'margin: 6%; width: 90%') {
                            doc.tr {
                                doc.th('keys')
                                doc.th('values')
                            }
                            data.each do | key, value |
                                doc.tr {
                                    doc.td(key.downcase)
                                    doc.td(value)
                                }
                            end
                        }
                    }
                }
            end.to_html
        end

        get '/' do
            responce('Hello, World, I\'m IONe Cloud' )
        end

        ### Method call handlers ###

        # Calling methods with one basic param
        get '/api/call/*/*' do | method, param |
            LOG "WebAPI | Method: #{method}, Param: #{param}", 'DEBUG'
            responce(IONe.new($client).send(method, param))   
        end

        # Calling methods without params or with hash-type params
        get '/api/call/*' do | method |
            LOG "WebAPI | Method: #{method}, Param: #{params}", 'DEBUG' if params.keys.size > 2
            responce(IONe.new($client).send(method, params)) if params.keys.size > 2
            LOG "WebAPI | Method: #{method}", 'DEBUG' if params.keys.size <= 2
            responce(IONe.new($client).send(method)) if params.keys.size <= 2
        end

        ### Documentation access definition ###
        get '/api/doc' do
            redirect 'http://185.66.68.7:8080'
        end

        ### Working with Users ###
        get '/api/user' do
            responce('Test out')
        end

        get '/api/user/*/*' do |user, vm|
            LOG "WebAPI | User: #{user}, VM: #{vm}", 'DEBUG'
            begin
                data = IONe.new($client).get_vm_data(vm.to_i)
            rescue => e
                LOG e.message, 'DEBUG'
            end
            LOG data, 'DEBUG'
            responce_html_table(data)
        end

        get '/api/user/*' do | user |
            begin
                data = {
                    :id => user, :name => onblock(:u, user.to_i) { |u| u.info! || u.name },
                    :vms => IONe.new($client).get_vm_by_uid(user.to_i)
                }
                LOG data, 'DEBUG'
                responce_html_table(data)
            rescue => e
                LOG e.message, 'DEBUG'
                responce(e.message)
            end
        end
    end
    run WebApi.run!
end

at_exit do
    WebApiEnv.exit
end