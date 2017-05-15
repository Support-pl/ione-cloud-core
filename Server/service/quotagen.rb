def NewQuota(login, vmquota, specs)
    quota = "/tmp/#{login}_quota.txt"
    File.open(quota, 'w'){ |file| file.puts \
    "
        VM=[
            CPU=\"#{specs[0]}\",
            MEMORY=\"#{specs[1]}\",
            SYSTEM_DISK_SIZE=\"#{specs[2]}\",
            VMS=\"#{vmquota}\",
    "
    }
    return quota
end