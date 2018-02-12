require 'rbvmomi'

VIM = RbVmomi::VIM

vim = VIM.connect(:host => 'btk-vcenter6-5.helpdesk.by', :insecure => true, :user => 'administrator@helpdesk.by', :password => 'ONuzy4N%m@~Wl?o')
dc = vim.find_datastore

vm = dc.find_vm('%vm_name%')

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