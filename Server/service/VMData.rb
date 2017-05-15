def GetVMID(createout)
    createout.chomp!
    i, vmid = createout.size - 1, ""
    while createout[i] != ':' do
        vmid += createout[i]
        i -= 1
    end
    return vmid.chop.reverse
end

def GetIP(vmid)
    config = `sh oneshow.sh #{vmid} | grep "ETH0_IP="`
    ip, i = "", config.size
    while config[i] != '"' do i -= 1 end
    i -= 1
    while config[i] != '"' do
        ip += config[i]
        i -= 1
    end
    return ip.reverse
end