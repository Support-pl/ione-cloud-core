class UserShowback

    attr_reader :showback, :total_cost

    def initialize uid, start_time, end_time
        @uid = uid

        vm_pool = VirtualMachinePool.new($client)
        vm_pool.info @uid

        @start_time = start_time
        @end_time   = end_time

        showback = vm_pool.showback(
            -2, start_month: @start_time[0], end_month: @end_time[0],
                start_year:  @start_time[1], end_year:  @end_time[1]        )['SHOWBACK_RECORDS']['SHOWBACK']
        @showback = showback.select { |vm| vm['UID'].to_i == @uid }

        @total_cost = @showback.inject(0){ |summ, vm| summ += vm['TOTAL_COST'].to_i }
    end
    def filter vms
        @showback = @showback.select { |vm| vms.include? vm['VMID'].to_i}
    end
end

class IONe
    def RetrieveShowback user_id, start_time = [-1, -1], end_time = [-1, -1], filter = []
        showback = UserShowback.new user_id, start_time, end_time

        showback.filter filter unless filter.nil? || filter == []

        return showback.showback, showback.total_cost
    end
end