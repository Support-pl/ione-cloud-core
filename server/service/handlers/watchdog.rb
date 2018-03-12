Thread.new do
    sleep(172800)
    until Time.now.hour == 2 do
        sleep(1800)
    end
    LOG "It's time to restart the server, to avoid the freezing of system ", 'WatchDog' 
    `sh #{ROOT}/service/handlers/reboot_key.sh &`
end