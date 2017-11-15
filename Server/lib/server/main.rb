########################################################
#   Методы для получения информации работе сервера     #
#         и управления некоторыми функциями            #
########################################################

class WHMHandler
    def locks_stat(key = nil)
        return $thread_locks
    end
    def version
        return VERSION
    end
    def uptime
        return fmt_time(Time.now.to_i - STARTUP_TIME)
    end
    def conf
        return CONF.privatise.out
    end
end