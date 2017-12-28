########################################################
#   Методы для получения информации работе сервера     #
#         и управления некоторыми функциями            #
########################################################

puts 'Extending Handler class by server-info getters'
class WHMHandler
    def locks_stat(key = nil)
        LOG_STAT(__method__.to_s, time())
        return $thread_locks
    end
    def version
        LOG_STAT(__method__.to_s, time())
        return VERSION
    end
    def uptime
        LOG_STAT(__method__.to_s, time())
        return fmt_time(Time.now.to_i - STARTUP_TIME)
    end
    def conf
        LOG_STAT(__method__.to_s, time())
        return CONF.privatise.out
    end
    def proc
        LOG_STAT(__method__.to_s, time())        
        return $proc
    end
end