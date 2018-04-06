########################################################
#   Методы для получения информации работе сервера     #
#         и управления некоторыми функциями            #
########################################################

puts 'Extending Handler class by server-info getters'
class IONe
    # @api private    
    def locks_stat(key = nil)
        LOG_STAT()
        id = Time.now.to_i.to_s(16)
        LOG_CALL(id, true, __method__)
        defer { LOG_CALL(id, false, __method__) }
        return $thread_locks
    end
    # Returns current running IONe Cloud Server version
    # @return [String]
    def version
        LOG_STAT()
        id = Time.now.to_i.to_s(16)
        LOG_CALL(id, true, __method__)
        defer { LOG_CALL(id, false, __method__) }
        return VERSION
    end
    # Returns IONe Cloud Server uptime(formated)
    # @return [String]
    def uptime
        LOG_STAT()
        id = Time.now.to_i.to_s(16)
        LOG_CALL(id, true, __method__)
        defer { LOG_CALL(id, false, __method__) }
        return fmt_time(Time.now.to_i - STARTUP_TIME)
    end
    # Returns CONF Hash as JSON, with crypted private data
    # @return [String] JSON
    def conf
        LOG_STAT()
        id = Time.now.to_i.to_s(16)
        LOG_CALL(id, true, __method__)
        defer { LOG_CALL(id, false, __method__) }
        return CONF.privatise.out
    end
    # @api private
    def reboot(pa)
        `sh #{ROOT}/service/handlers/reboot_key.sh &` if pa['ss']
    end
end