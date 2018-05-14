tg_token = '559508786:AAFihmxUyncrdBarA_fQyIpyLJl9o0Z5gDE'
require '../../debug_lib.rb'
require 'telegram/bot'

$USERS = ['slnt_opp']
$ACCOUNTS = Hash.new('none')
    $ACCOUNTS['slnt_opp'] = 0
    $ACCOUNTS['alisupportby'] = 0

require "#{ROOT}/modules/telegrambot/handlers.rb"

def space_gen(number)
    res = ""
    for i in 0..number do
        res += ' '
    end
    return res
end

tgBotThread = Thread.new do
    Telegram::Bot::Client.run(tg_token) do |bot|
        begin
            bot.listen do |msg|

                case msg.class.to_s
                when 'Telegram::Bot::Types::Message'
                    case msg.text
                    when *['/start', 'Войти в другой аккаунт']
                        TgHandler.new.start(bot, msg)
                    when *['Заказать']
                        TgHandler.new.order(bot, msg)
                    when *['/help', 'Помощь', 'Help']
                        TgHandler.new.help(bot, msg) if $USERS.include? msg.from.username
                    when *['/menu', 'Menu', 'Меню']
                        TgHandler.new.menu(bot, msg) if $USERS.include? msg.from.username
                        TgHandler.new.start(bot, msg) if !$USERS.include? msg.from.username
                    when /\/vm \d+/
                        LOG "TelegramBot | VM#{msg.text.split(' ').last} data required", 'DEBUG'
                        TgHandler.new.vm(bot, msg) if $USERS.include? msg.from.username
                    when /\/vms \d+/, /\/vms/, 'Виртуальные Машины' then
                        LOG "TelegramBot | User #{$ACCOUNTS[msg.from.username].to_s} VMs required", 'DEBUG'
                        TgHandler.new.vms(bot, msg) if $USERS.include? msg.from.username
                    
                    jwhen '/ping'
                        LOG 'TelegramBot | Ping query accepted', 'TelegramBot'
                        bot.api.send_message(
                            chat_id: msg.chat.id,
                            text: 'Ping probe successful?.. or... :)'        
                        )
                    when *['Аутентификация', '/auth', 'Authentificate']
                        TgHandler.new.auth(bot, msg) if !$USERS.include? msg.from.username
                    when /\d+/
                        TgHandler.new.auth_code_entered(bot, msg)
                    when nil
                        if !msg.contact.phone_number.nil? then
                            TgHandler.new.auth_by_number(bot, msg)
                        else
                            puts 'text is nil'
                        end
                    else
                        puts msg.text
                    end
                when 'Telegram::Bot::Types::CallbackQuery'
                    case msg.data
                    when *['/menu', 'Menu', 'Меню']
                        TgHandler.new.menu(bot, msg) if $USERS.include? msg.from.username
                        # TgHandler.new.start(bot, msg) if !$USERS.include? msg.from.username
                    when /\/vm \d+/
                        puts msg.data
                        LOG "TelegramBot | VM#{msg.data.split(' ').last} data required", 'DEBUG'
                        TgHandler.new.vm(bot, msg) if $USERS.include? msg.from.username
                    when /\/vms \d+/, /\/vms/ then
                        TgHandler.new.vms(bot, msg) if $USERS.include? msg.from.username
                    when /\/vm_update \d+/
                        TgHandler.new.vm_update(bot, msg) if $USERS.include? msg.from.username
                    when /\/vm_resume \d+/
                        TgHandler.new.vm_resume(bot, msg) if $USERS.include? msg.from.username
                    when /\/vm_poweroff \d+/
                        TgHandler.new.vm_poweroff(bot, msg) if $USERS.include? msg.from.username
                    when /\/vm_poweroff_sure \d+/
                        TgHandler.new.vm_poweroff_sure(bot, msg) if $USERS.include? msg.from.username
                    when /\/vm_reboot \d+/
                        TgHandler.new.vm_reboot(bot, msg) if $USERS.include? msg.from.username
                    when /\/vm_reboot_sure \d+/
                        TgHandler.new.vm_reboot_sure(bot, msg) if $USERS.include? msg.from.username
                    else
                        puts msg.data
                    end
                else
                    puts msg.class
                end
            end
        rescue => e
            puts e.message
            puts e.backtrace
        end
    end
end

tgBotThread.join