require 'nori'
require 'active_support'
require 'active_support/core_ext'

quota = { 'CPU' => 1, 'MEMORY' => 2048, 'VMS' => 1, 'SYSTEM_DISK_SIZE' => -1 }

puts quota.to_xml(:root => 'VM')