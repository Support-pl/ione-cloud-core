########################################################
#          Функция запуска ansible-скриптов            #
########################################################

ANSIBLE_HOST = CONF['AnsibleServer']['host']
ANSIBLE_HOST_PORT = CONF['AnsibleServer']['port']
ANSIBLE_HOST_USER = CONF['AnsibleServer']['user']
require "#{CONF['AnsibleServer']['data-getters-url']}"
require 'net/ssh'
require 'net/sftp'

class WHMHandler
    def AnsibleControllerNew(params)
        host, playbook, service = params['host'], params['playbook'], params['service']
        LOG params.out, 'DEBUG'
        return if params['out'] == true
        ip, err = host.split(':').first, ""
        installid = service[0..2] + Time.now.to_i.to_s(16)
        LOG "#{service} should be installed on #{ip}, installation ID is: #{installid}", "AnsibleController"
        tid = WHM.new.LogtoTicket(
            subject: "#{ip}: #{service.capitalize} install",
            message: "
            IP: #{ip}
            Service for install: #{service.capitalize}
            Install-ID: #{installid}",
            method: __method__.to_s,
            priority: 'Low'
        )['id']
        at_exit do
            LOG 'Wiping hosts and pb files', 'DEBUG'
            begin
                ssh.sftp.remove!("/tmp/#{installid}.ini")
            rescue => e
                LOG "#{installid}.ini was not removed from remote FS", 'DEBUG'#'AnsibleController'
            end
            begin
                File.delete("/tmp/#{installid}.ini")
            rescue => e
                LOG "#{installid}.ini was not removed from local FS", 'DEBUG'#'AnsibleController'
            end
            begin
                ssh.sftp.remove!("/tmp/#{installid}.yml")
            rescue => e
                LOG "#{installid}.yml was not removed from remote FS", 'DEBUG'#'AnsibleController'
            end
            begin
                File.delete("/tmp/#{installid}.yml")
            rescue => e
                LOG "#{installid}.yml was not removed from local FS", 'DEBUG'#'AnsibleController'
            end
        end
        LOG 'pre-thread', 'DEBUG'
        # obj, id = MethodThread.new(:method => __method__).with_id # Получение объекта MethodThread и его ID
        # $thread_locks[:ansiblecontroller] << obj.thread_obj( # Запись в объект объекта потока
        Thread.new do
            # until $thread_locks[:ansiblecontroller][0].id == id do sleep(30) end
                begin
                err = "Error while connecting to Ansible-server"
                LOG 'Connecting to Ansible', 'DEBUG'            
                Net::SSH.start(ANSIBLE_HOST, ANSIBLE_HOST_USER, :port => ANSIBLE_HOST_PORT, :password => 'Nhb500Gznmcjn') do | ssh |
                    err = "Error while creating temporary playbook file occurred"
                    File.open("/tmp/#{installid}.yml", 'w') { |file| file.write(playbook.gsub('{{group}}', installid)) }
                    err = "Error while uploading playbook occurred"
                    ssh.sftp.upload!("/tmp/#{installid}.yml", "/tmp/#{installid}.yml")
                    err = "Error while creating temporary ansible-inventory file occurred"
                    File.open("/tmp/#{installid}.ini", 'w') { |file| file.write("[#{installid}]\n#{host}\n") }
                    err = "Error while uploading ansible-inventory occurred"
                    ssh.sftp.upload!("/tmp/#{installid}.ini", "/tmp/#{installid}.ini")
                    LOG 'PB and hosts have been generated', 'DEBUG'
                    err = "Error while executing playbook occured"
                    LOG 'Executing PB', 'DEBUG'
                    $pbexec = host.exec!("ansible-playbook /tmp/#{installid}.yml -i /tmp/#{installid}.ini")
                    LOG 'PB has been Executed', 'DEBUG'
                    def status(regexp)
                        return $pbexec.last[regexp].split(/=/).last.to_i
                    end
                    WHM.new.LogtoTicket(
                        message: "
                        IP: #{ip}
                        Service for install: #{service.capitalize}
                        Log: \n    #{$playbookexec.join("\n    ")}",
                        method: __method__.to_s,
                        priority: "#{(status(/failed=(\d*)/) | status(/unreachable=(\d*)/) == 0) ? 'Low' : 'High'}",
                        id: tid
                    )
                    LOG "#{service} installed on #{ip}", "AnsibleController"
                end
            rescue => e
                # $thread_locks[:ansiblecontroller].delete_at 0 # Удаление себя из очереди на выполнение
                LOG "An Error occured, while installing #{service} on #{ip}: #{err}, Code: #{e.message}", "AnsibleController"
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
            # $thread_locks[:ansiblecontroller].delete_at 0        
        end
        # )
        LOG 'func-end', 'DEBUG'
    end
end