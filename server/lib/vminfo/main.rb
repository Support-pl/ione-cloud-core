########################################################
#   Методы для получения информации о ВМ и Аккаунтах   #
########################################################

puts 'Extending Handler class by VM and User info getters'
class IONe
    def VM_XML(vmid)
        LOG_STAT()        
        vm = onblock(VirtualMachine, vmid)
        return vm.info! || vm.to_xml
    end

    def GetIP(vmid) # Получение IP адреса ВМ
        LOG_STAT()
        onblock(:vm, vmid) do |vm|
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
        LOG_STAT()        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.state
    end
    def STATE_STR(vmid) # Состояние ВМ в виде строки
        LOG_STAT()        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.state_str
    end
    def LCM_STATE(vmid) # Состояние в жизненном цикле ВМ в цифровом виде
        LOG_STAT()        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.lcm_state
    end
    def LCM_STATE_STR(vmid) # Состояние в жизненном цикле ВМ в виде строки
        LOG_STAT()        
        vm = onblock(VirtualMachine, vmid.to_i)
        return vm.info! || vm.lcm_state_str
    end
    def get_vm_data(vmid) # Получение найважнейших данных о ВМ
        proc_id = proc_id_gen(__method__)
        onblock(:vm, vmid) do | vm |
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
    def GetSnapshotList(vmid)
        LOG_STAT()        
        return onblock(VirtualMachine, vmid).list_snapshots
    end
end