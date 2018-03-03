########################################################
#   Методы для получения информации о ВМ и Аккаунтах   #
########################################################

puts 'Extending Handler class by VM and User info getters'
class IONe
    def VM_XML(vmid)
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid)
        return vm.info! || vm.to_xml
    end

    def GetIP(vmid) # Получение IP адреса ВМ
        LOG_STAT(__method__.to_s, time())
        onblock('vm', vmid) do |vm|
            vm.info!
            vm, ip = vm.to_hash['VM'], 'nil'
            begin
                # Если ВМ создана через шаблон ON, то информация об её сетевых устройствах будет вшита в шаблон
                ip = vm['TEMPLATE']['NIC']['IP'] if !vm['TEMPLATE']['NIC']['IP'].nil?
            rescue # Если все же нет - юудет ошибка чтения из Hash
            end
            begin
                # Тогда, если ВМ правильно импортирована, адрес будет считан системой мониторинга и запиан в соответствующее поле
                ip = vm['MONITORING']['GUEST_IP'] if !vm['MONITORING']['GUEST_IP'].nil? && !vm['MONITORING']['GUEST_IP'].include?(':')
                # В этом поле так же может содержаться IPv6 адрес, посему делаем проверку
            rescue
            end
            begin
                # И последняя возможность получить адрес: другое поле в мониторинге, однако сюда записываются все найденные адреса ВМ
                ip = vm['MONITORING']['GUEST_IP_ADDRESSES'].split(',').first if !vm['MONITORING']['GUEST_IP_ADDRESSES'].nil?
                # т.е. как IPv4, так и IPv6, а инода MAC, VPN, локальные и тд
            rescue
            end
            return 'nil' if ip.nil? || ip.include?(':')
            return ip if !ip.include?(':')
        end
    end
    def GetVMIDbyIP(ip) # Получение vmid по IP адресу
        vm_pool = VirtualMachinePool.new(@client)
        vm_pool.info_all!
        vm_pool.each do |vm| # Прочесываем пул, пока не найдем ВМ с IP равным заданному
            break if nil
            begin
                return vm.id if ip.chomp == GetIP(vm.id).chomp
            rescue
            end
        end
        return nil
    end
    def STATE(vmid) # Состояние ВМ в цифровом виде
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.state
    end
    def STATE_STR(vmid) # Состояние ВМ в виде строки
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.state_str
    end
    def LCM_STATE(vmid) # Состояние в жизненном цикле ВМ в цифровом виде
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.lcm_state
    end
    def LCM_STATE_STR(vmid) # Состояние в жизненном цикле ВМ в виде строки
        LOG_STAT(__method__.to_s, time())        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.lcm_state_str
    end
    def get_vm_data(vmid) # Получение найважнейших данных о ВМ
        proc_id = proc_id_gen(__method__)
        onblock('vm', vmid) do | vm |
            vm.info!
            vm_hash = vm.to_hash['VM']
            return kill_proc(proc_id) || {
                # "Имя, владелец, id владельца машины"
                'NAME' => vm_hash['NAME'], 'OWNER' => vm_hash['UNAME'], 'OWNERID' => vm_hash['UID'],
                # IP, кластер и упрощенное состояние ВМ
                'IP' => GetIP(vmid), 'HOST' => get_vm_host(vmid), 'STATE' => LCM_STATE(vmid) != 0 ? LCM_STATE_STR(vmid) : STATE_STR(vmid),
                # Технические характеристики ВМ
                'CPU' => vm_hash['TEMPLATE']['VCPU'], 'RAM' => vm_hash['TEMPLATE']['MEMORY'],
                # Данные об истории появления ВМ
                'IMPORTED' => vm_hash['TEMPLATE']['IMPORTED'].nil? ? 'NO' : 'YES'
            }
        end if vmid.class != VirtualMachine # Если приходит vmid
        vm, vmid = vmid, vmid.id # Если приходит объект
        vm_hash = vm.to_hash['VM']
        return kill_proc(proc_id) || {
            'NAME' => vm_hash['NAME'], 'OWNER' => vm_hash['UNAME'], 'OWNERID' => vm_hash['UID'],
            'IP' => GetIP(vmid), 'HOST' => get_vm_host(vmid), 'STATE' => LCM_STATE(vmid) != 0 ? LCM_STATE_STR(vmid) : STATE_STR(vmid),
            'CPU' => vm_hash['TEMPLATE']['VCPU'], 'RAM' => vm_hash['TEMPLATE']['MEMORY'],
            'IMPORTED' => vm_hash['TEMPLATE']['IMPORTED'].nil? ? 'NO' : 'YES'
        }
    end
    def get_vm_host(vmid) # Получение имени кластера, которому принадлежит ВМ
        onblock('vm', vmid, $client) do | vm |
            vm.info!
            vm = vm.to_hash['VM']["HISTORY_RECORDS"]['HISTORY'] # Поиск инф-ции осуществляется через историю перемещений ВМ
            return vm.last['HOSTNAME'] if vm.class == Array # Если перемещения были, то берем последнюю запись
            return vm['HOSTNAME'] if vm.class == Hash # Если нет, то единственную запись
            return nil # Если информация не найдена(P = 0.(000)9%) возврат пустого значения
        end
    end
    def compare_info(vms = []) # Получение списка ВМ находящихся под управлением ON с соответсвующими данными
        LOG_STAT(__method__.to_s, time())
        proc_id, info, $free = proc_id_gen(__method__), "Method-inside error", nil
        def get_lease(vn) # Функция генерирующая список свободных IP
            vn = (vn.info! || vn.to_hash)["VNET"]["AR_POOL"]["AR"][0]
            return if (vn['IP'] && vn['SIZE']).nil?
            pool = ((vn["IP"].split('.').last.to_i)..(vn["IP"].split('.').last.to_i + vn["SIZE"].to_i)).to_a.map! { |item| vn['IP'].split('.').slice(0..2).join('.') + "." + item.to_s }
            leases = vn['LEASES']['LEASE'].map {|lease| lease['IP']}
            vn['LEASES']['LEASE'].each do | lease |
                pool.delete(lease['IP'])
            end
            $free.push pool
        end
        
        vm_pool, info = VirtualMachinePool.new($client), []

        vm_pool.info_all!
        vm_pool.each do |vm| # Генерация объектов типа VM+DATA
            break if vm.nil?
            next if !vms.empty? && !vms.include?(vm.id)
            vm = vm.to_hash['VM']
            info << {
                :vmid => vm['ID'], :userid => vm['UID'], :host => get_vm_host(vm['ID']),
                :login => vm['UNAME'], :ip => GetIP(vm['ID']), :state => (LCM_STATE(vm['ID']) != 0 ? LCM_STATE_STR(vm['ID']) : STATE_STR(vm['ID']))
            }
        end

        vn_pool, $free = VirtualNetworkPool.new(@client), []
        vn_pool.info_all!
        vn_pool.each do | vn |
            break if vn.nil?
            begin
                get_lease vn
            rescue
            end
        end

        host_pool, hosts = HostPool.new($client), [] # Номинальное получение списка доступных кластеров
        host_pool.info_all!
        host_pool.each do | host |
            hosts << host.name
        end
        return kill_proc(proc_id) || info, $free, hosts
    end
    def GetUserInfo(userid)
        user = onblock(User, userid)
        LOG_STAT(__method__.to_s, time())
        return user.info! || user.to_xml
    end
    def DatastoresMonitoring(type) # Мониторинг занятости дисков на NAS*
        LOG_STAT(__method__.to_s, time())        
        return "WrongTypeExeption: type '#{type}' not exists" if type != 'sys' && type != 'img'

        def sizeConvert(mb) # Конвертация мегабайт в гига- либо тера- байты
            if mb.to_f / 1024 > 768 then
                return "#{(mb.to_f / 1048576.0).round(2).to_s}TB"
            else
                return "#{(mb.to_f / 1024.0).round(2).to_s}GB" 
            end
        end

        img_pool, mon = DatastorePool.new(@client), []
        img_pool.info_all!
        img_pool.each do | img |
            mon << { 
                'id' => img.id, 'name' => img.name.split('(').first, :full_size => sizeConvert(img.to_hash['DATASTORE']['TOTAL_MB']),
                'used' => sizeConvert(img.to_hash['DATASTORE']['USED_MB']),
                'type' => img.to_hash['DATASTORE']['TEMPLATE']['DRIVE_TYPE'],
                'deploy' => img.to_hash['DATASTORE']['TEMPLATE']['DEPLOY']
            } if img.short_type_str == type && img.id > 2
        end
        return mon
    end
    def HostsMonitoring() # Мониторинг резерваций CPU и RAM
        LOG_STAT(__method__.to_s, time())        

        def sizeConvert(mb)
            if mb.to_f / 1048576 > 768 then
                return "#{(mb.to_f / 1073741824.0).round(2).to_s}TB"
            else
                return "#{(mb.to_f / 1048576.0).round(2).to_s}GB" 
            end
        end

        host_pool, mon = HostPool.new($client), []
        host_pool.info!
        host_pool.each do | host |
            host = host.to_hash['HOST']
            mon << { 
                :id => host['ID'], :name => host['NAME'], :full_size => sizeConvert(host.to_hash['HOST_SHARE']['TOTAL_MEM']),
                :reserved => sizeConvert(host.to_hash['HOST_SHARE']['MEM_USAGE']),
                :running_vms => host.to_hash['HOST_SHARE']['RUNNING_VMS'],
                :cpu => "#{(host.to_hash['HOST_SHARE']['USED_CPU'].to_f / host.to_hash['HOST_SHARE']['TOTAL_CPU'].to_f * 100).round(2).to_s}%"
            }
        end
        return mon
    end
    def proc
        return $proc
    end
end