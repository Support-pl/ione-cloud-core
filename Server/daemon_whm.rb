require 'daemons'

Daemons.run('whmconnect.rb') do
    loop do
        sleep(10)
    end
end