require 'rubygems'
require 'net/smtp'
from = 'opennebula@support.by'
to = 'monitoring@support.by'
subject = 'Мониторинг состояний ВМ'

query = `mysql opennebula -BNe "select distinct vmid FROM vm_monitoring WHERE body NOT LIKE '%guestToolsRunning%'"`
query = query.split
text = "У этих ВМ не работают VMWareTools:\n"
query.each do | item |
    text << "<a href='https://cloud.support.by/#vms-tab/#{item.to_i}'> " << item << " </a>, "
end

query = `mysql opennebula -BNe "select oid from vm_pool where lcm_state = 16"`
query = query.split
text << "\n\n-------------\n\nСледующие ВМ имеют статус \"UNKNOWN\":\n"
query.each do | item |
    text << "<a href='https://cloud.support.by/#vms-tab/#{item}'> " << item << " </a>, "
end

query = `mysql opennebula -BNe "select oid from vm_pool where state = 8"`
query = query.split
text << "\n\n-------------\n\nСледующие ВМ имеют статус \"POWEROFF\":\n"
query.each do | item |
    text << "<a href='https://cloud.support.by/#vms-tab/#{item}'> " << item << " </a>, "
end

query = `mysql opennebula -BNe "select oid from vm_pool where state = 5"`
query = query.split
text << "\n\n-------------\n\nСледующие ВМ имеют статус \"SUSPENDED\":\n"
query.each do | item |
    text << "<a href='https://cloud.support.by/#vms-tab/#{item}'> " << item << " </a>, "
end

query = `mysql opennebula -BNe "select oid from vm_pool where state = 1"`
query = query.split
text << "\n\n-------------\n\nСледующие ВМ имеют статус \"PENDING\":\n"
query.each do | item |
    text << "<a href='https://cloud.support.by/#vms-tab/#{item}'> " << item << " </a>, "
end

query = `mysql opennebula -BNe "select oid from vm_pool where state = 2"`
query = query.split
text << "\n\n-------------\n\nСледующие ВМ имеют статус \"HOLD\":\n"
query.each do | item |
    text << "<a href='https://cloud.support.by/#vms-tab/#{item}'> " << item << " </a>, "
end

query = `mysql opennebula -BNe "select oid from vm_pool where state = 4"`
query = query.split
text << "\n\n-------------\n\nСледующие ВМ имеют статус \"STOPPED\":\n"
query.each do | item |
    text << "<a href='https://cloud.support.by/#vms-tab/#{item}'> " << item << "  </a>, "
end

message = ""
message << "From: <#{from}>\n"
message << "To: #{to}\n"
message << "Subject: #{subject}\n"
message << text
Net::SMTP.new('localhost', 25).start('mail.support.by') do |smtp|
    smtp.send_message message, from, to
end 