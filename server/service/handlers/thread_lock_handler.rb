class MethodThread
    def initialize(params)
        @start_time = Time.now.to_i # Время запуска работы потока(либо создания объекта)
        @timeout = params[ :timeout ] # Таймаут работы потока
        @id = @start_time.to_s.hash # ID объекта, для учета очереди
        @method = params[ :method ].to_s # Название метода выполняющегося в потоке
        @active = false # Был ли запущен поток
        @wait = params[ :wait ].nil? ? false : params[ :wait ] # Пременная определяющая будет ли ThreadKiller ждать завершения потока
    end
    def with_id # Возврат id объекта при его создании 
        return self, @id
    end
    def id # возврат id объекта
        return @id
    end
    def timeout? # достигнут ли timeout выполнения
        return (Time.now.to_i - @start_time) >= @timeout if !@timeout.nil?
        return false # если таймаут не задан
    end
    def thread_obj(thread) # добавление в объект ссылки на объект потока
        @thread = thread
        return self
    end
    def thread # возврат объекта потока
        return @thread
    end
    def method # возврат названия метода
        return @method 
    end
    def info # возврат информации об объекте
        return "TimeStarted: #{@start_time}, Timeout: #{@timeout}, ID: #{@id}, Thread: #{@thread}, Method: #{method}, Active: #{@active}"
    end
    def start # запуск отсчета до таймаута
        @start_time = Time.now.to_i        
        @active = true
    end        
    def active? # проверка был ли запущен поток
        return @active
    end
    def kill_if_wait # завершение потока в случае достижения таймаута, но если требуется ожидание его завершения
        if @wait && timeout? then
            Thread.kill @thread
            return true
        end
        return false
    end
end