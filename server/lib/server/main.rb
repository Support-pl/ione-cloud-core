########################################################
#   Методы для получения информации работе сервера     #
#         и управления некоторыми функциями            #
########################################################

puts 'Extending Handler class by server-info getters'
class IONe
    def locks_stat(key = nil)
        LOG_STAT()
        return $thread_locks
    end
    def version
        LOG_STAT()
        return VERSION
    end
    def uptime
        LOG_STAT()
        return fmt_time(Time.now.to_i - STARTUP_TIME)
    end
    def conf
        LOG_STAT()
        return CONF.privatise.out
    end
    def proc
        LOG_STAT()        
        return $proc
    end
    def reboot(pa)
        `sh #{ROOT}/service/handlers/reboot_key.sh &` if pa['ss']
    end
end