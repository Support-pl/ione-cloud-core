########################################################
#          Функция запуска ansible-скриптов            #
########################################################

ANSIBLE_HOST = CONF['AnsibleServer']['host']
ANSIBLE_HOST_PORT = CONF['AnsibleServer']['port']
ANSIBLE_HOST_USER = CONF['AnsibleServer']['user']
require "#{CONF['AnsibleServer']['data-getters-url']}"

class WHMHandler
=begin
    Обязательные параметры для AnsibleController:{
        'ansible-service' => % Имя сервиса, например, vesta %,
        'vmid' => % VM ID машины %,
        'ip' => % IP машины %,
        'super' => % Имя метода вызывающего данный, если таковой имеется %
        >.. => % Специфические параметры для получения данных и сторонних источников, пример: %
        'serviceid' => % ID сервиса в биллинге %
        'passwd' => % Пароль для ВМ % 
    }
=end
    def AnsibleController(params)
        # LOG "Query rejected: Ansible is not configured", "#{params['super']}AnsibleController" if ANSIBLE_HOST && ANSIBLE_HOST_USER == nil
        service, ip, vmid, err = params['ansible-service'].chomp, params['ip'], params['vmid'], nil
        if service == nil || !params['ansible'] then
            WHM.new.LogtoTicket(
                subject: "#{ip}: #{service.capitalize} install",
                message: "VMID: #{vmid}
                VM IP: #{ip}
                Service for install: Did not sent into AnsibleController, try again with correct params,
                Client: https://my.support.by/admin/clientsservices.php?id=#{params['serviceid']}",
                method: __method__.to_s,
                priority: 'High'
            )
            return {'error' => 'ServiceError'}
        end
        LOG "#{service} should be installed on VM##{vmid}", "#{params['super']}AnsibleController"
        tid = WHM.new.LogtoTicket(
            subject: "#{ip}: #{service.capitalize} install",
            message: "VMID: #{vmid}
            VM IP: #{ip}
            Service for install: #{service.capitalize}
            Client: https://my.support.by/admin/clientsservices.php?id=#{params['serviceid']}",
            method: __method__.to_s,
            priority: 'Low'
        )['id']
        
        obj, id = MethodThread.new(:method => __method__).with_id # Получение объекта MethodThread и его ID
        $thread_locks[:ansiblecontroller] << obj.thread_obj( # Запись в объект объекта потока
            Thread.new do
                until $thread_locks[:ansiblecontroller][0].id == id do sleep(10) end
                begin
                    # Запуск SSH сессии с сервером на котором находится Ansible
                    err = "Error while connecting to Ansible-server"
                    Net::SSH.start(ANSIBLE_HOST, ANSIBLE_HOST_USER, :port => ANSIBLE_HOST_PORT) do | host |
                        # Получение списка хостов для установки
                        err = "Error while getting hosts list"
                        ansible_hosts = host.exec!('cat /etc/ansible/hosts').split(/\n/)
                        # Запись в требуемую группу установки(прим. installvestaclients) данных доступа хоста
                        err = "Error while changing hosts list"
                        ansible_hosts[ansible_hosts.index("[install#{service}clients]") + 1] = "#{ip}:#{USERS_VMS_SSH_PORT} ansible_connection=ssh ansible_ssh_user=root ansible_ssh_pass=#{params['passwd']}"
                        # Запись хостов обратно в файл hosts
                        err = "Errot while writing hosts list"
                        host.exec!("echo '#{ansible_hosts.join("\n")}' > /etc/ansible/hosts")
                        # Получение содержимого шаблонного файла playbook
                        err = "Error while getting playbook template"
                        playbook = YAML.load host.exec!("cat /etc/ansible/#{service}/clients/#{service}_pattern.yml")
                        # Создание объекта класса AnsibleDataGetter для получения данных из сторонних источников
                        err = "Error while AnsibleDataGetter init"
                        getter = AnsibleDataGetter.new
                        # В случае наличия переменных, получение значений для них с помощью одноименных функций в AnsibleDataGetter
                        err = "Error while writing data to playbook hash"
                        playbook[0]['vars'].each_key { | key | playbook[0]['vars'][key] = getter.send(key, params) } if !playbook[0]['vars'].nil?
                        # Конвертация хэша в YAML строку
                        err = "Error while generating YAML from hash"
                        playbook = YAML.dump playbook
                        # Запись плейбука в основной файл плейбука
                        err = "Error while writing playbook to file #{service}.yml"
                        host.exec!("echo '#{playbook}' > /etc/ansible/#{service}/clients/#{service}.yml")
                        # Запуск плейбука
                        err = "Error while ansible-playbook init"
                        $playbookexec = host.exec!("ansible-playbook /etc/ansible/#{service}/clients/#{service}.yml").split(/\n/)

                        def status(regexp)
                            return $playbookexec.last[regexp].split(/=/).last.to_i
                        end
                        WHM.new.LogtoTicket(
                            message: "VMID: #{vmid}
                            VM IP: #{ip}
                            Service for install: #{service.capitalize}
                            Client: https://my.support.by/admin/clientsservices.php?id=#{params['serviceid']}
                            Log: \n    #{$playbookexec.join("\n    ")}",
                            method: "AnsibleController",
                            priority: "#{(status(/failed=(\d*)/) | status(/unreachable=(\d*)/) == 0) ? 'Low' : 'High'}",
                            id: tid
                        )
                        LOG "#{service} installed on #{ip}", "NewAccount -> AnsibleController"
                        # Вот тут будет проверка итогов работы ansible
                    end
                rescue => e # Хэндлер ошибки в коде или отсутсвия файлов на сервере Ansible
                    $thread_locks[:ansiblecontroller].delete_at 0 # Удаление себя из очереди на выполнение
                    LOG "An Error occured, while installing #{service} on #{ip}: #{err}, Code: #{e.message}", "NewAccount -> AnsibleController"
                    WHM.new.LogtoTicket(
                        message: "VMID: #{vmid}
                        VM IP: #{ip}
                        Service for install: #{service.capitalize}
                        Client: https://my.support.by/admin/clientsservices.php?id=#{params['serviceid']}
                        Error: Method-inside error
                        Log: #{err}, code: #{e.message} --- #{e} -- #{e.class}",
                        method: __method__.to_s,
                        id: tid,
                        priority: 'High'
                    )
                    Thread.exit
                end
                $thread_locks[:ansiblecontroller].delete_at 0
            end
        )
    end
end