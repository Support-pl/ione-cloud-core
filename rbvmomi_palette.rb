require 'rbvmomi'

VIM = RbVmomi::VIM

servInst = VIM.connect(
    :host => 'btk-vcenter6-5.helpdesk.by', :insecure => true,
    :user => 'administrator@helpdesk.by', :password => 'ONuzy4N%m@~Wl?o'
).serviceInstance


# Reconfigure VM Resources Limits
    vm = servInst.find_datacenter.find_vm('one-261-test')

    vm.ReconfigVM_Task({
        'spec' => {
            'cpuAllocation' => {
                'limit' => cpu_limit
            },
            'memoryAllocation' => {
                'limit' => ram_limit
            }
        }
    })

    disk = vm.disks.first
    disk.storageIOAllocation.limit = 300
    disk.backing.sharing = nil

    cfg = {
        :deviceChange => [
            {
                :device => disk,
                :operation => :edit
            }
        ]
    }

    vm.ReconfigVM_Task(:spec => cfg).wait_for_completion

# ENDDDD

# Getting Host(Cluster) Monitoring Data
    summary = servInst.find_datacenter.find_compute_resource('vCloud').summary
    
# ENDDDD
