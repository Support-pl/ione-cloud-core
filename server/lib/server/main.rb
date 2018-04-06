########################################################
#   Методы для получения информации работе сервера     #
#         и управления некоторыми функциями            #
########################################################

puts 'Extending Handler class by server-info getters'
class IONe
    # @api private    
    def locks_stat(key = nil)
        LOG_STAT()
        return $thread_locks
    end
    # Returns current running IONe Cloud Server version
    # @return [String]
    def version
        LOG_STAT()
        return VERSION
    end
    # Returns IONe Cloud Server uptime(formated)
    # @return [String]
    def uptime
        LOG_STAT()
        return fmt_time(Time.now.to_i - STARTUP_TIME)
    end
    # Returns CONF Hash as JSON, with crypted private data
    # @return [String] JSON
    def conf
        LOG_STAT()
        return CONF.privatise.out
    end
    # @api private
    def reboot(pa)
        `sh #{ROOT}/service/handlers/reboot_key.sh &` if pa['ss']
    end
end