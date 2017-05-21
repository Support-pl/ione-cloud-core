def NewQuota(login, vmquota, disk)
    quota = "VM=[
            CPU=\"-2\",
            MEMORY=\"-2\",
            SYSTEM_DISK_SIZE=\"#{disk}\",
            VMS=\"-2\",]"
    }
    return quota
end