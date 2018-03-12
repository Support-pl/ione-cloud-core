class IONe
    def get_vm_by_uid(uid)
        vmp = VirtualMachinePool.new($client)
        vmp.info_all!
        vmp.each do | vm |
            return vm.id if vm.uid(false) == uid
        end
        return 'none'
    end
    def get_uid_by_name(name)
        up = UserPool.new($client)
        up.info_all!
        up.each do | u |
            return u.id.to_i if u.name == name
        end
        return 'none'        
    end
    def get_vm_by_uname(name)
        userid = get_uid_by_name(name)
        vmid = get_vm_by_uid(userid)
        return { :vmid => vmid, :userid => userid, :ip => GetIP(vmid) }
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

        return kill_proc(proc_id) || info if !vms.empty?

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
end