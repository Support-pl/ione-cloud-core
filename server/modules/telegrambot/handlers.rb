class TgHandler
    def start(bot, msg)
        bot.api.send_message(
            chat_id: msg.chat.id,
            text: 'Привет, я IONe Бот!',
            reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                keyboard: [ 'Меню', 'Аутентификация', 'Помощь' ], one_time_keyboard: true
            )
        )
    end

    ### Auth machine ###

    $CODES = {}

    def auth(bot, msg)
        bot.api.send_message(
            chat_id: msg.chat.id,
            text: 'Выберите способ аутентификации:',
            reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                keyboard: [
                    Telegram::Bot::Types::KeyboardButton.new(
                        text: 'по Номеру Телефона',
                        request_contact: true
                        ),
                    'Назад'
                ], one_time_keyboard: true
            )
        )
    end
    def auth_by_number(bot, msg)
        if msg.from.username.nil? then
            bot.api.send_message(
                chat_id: msg.chat.id,
                text: "Нет username, добавьте свой в настройках Telegram"     
            )
            start(bot, msg)
            return
        end
        $CODES[msg.from.username] = 112233 #rand(100000..1000000)
        puts $CODES[msg.from.username]
        bot.api.send_message(
            chat_id: msg.chat.id,
            text: "Введите код из СМС:"     
        )
    end
    def auth_code_entered(bot, msg)
        if msg.text.to_i != $CODES[msg.from.username] then
            bot.api.send_message(
                chat_id: msg.chat.id,
                text: "Код неверен!" 
            )
            start(bot, msg)
            return
        end
        $USERS << msg.from.username
        $ACCOUNTS[msg.from.username] = 0
        bot.api.send_message(
            chat_id: msg.chat.id,
            text: "Аутентификация прошла успешно!" 
        )
        menu(bot, msg)
    end

    ####################
    
    def order(bot, msg)
        kb = [
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Telegram', url: 't.me/spby_bot'),
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Наш сайт', url: 'support.by'),
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Личный кабинет SPBY', url: 'https://my.support.by/submitticket.php'),
            Telegram::Bot::Types::InlineKeyboardButton.new(text: '⟲ Назад', callback_data: '/menu')
        ]
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)        
        bot.api.send_message(
                chat_id: msg.chat.id,
                text: 'Вы можете с нами связаться используя:',
                reply_markup: markup
        ) 
    end
    def menu(bot, msg)
        bot.api.send_message(
            chat_id: msg.class.to_s.split('::').last == 'Message' ? msg.chat.id : msg.message.chat.id,
            text: 'Что будем делать?',
            reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                keyboard: [ 'Виртуальные Машины', 'Заказать', 'Помощь', 'Войти в другой аккаунт' ], one_time_keyboard: true
            )
        )
    end
    def vm_handler(bot, msg)
        begin
            vmid = msg.text.split(' ').last.to_i
        rescue
            vmid = msg.data.split(' ').last.to_i
        end
        msg = msg.message if msg.class.to_s == 'Telegram::Bot::Types::CallbackQuery'
        data = IONe.new($client).get_vm_data(vmid)
        
        message = 
        "Виртуальная машина *#{vmid.to_s}*\n\n" +
        "*Имя*: #{data['NAME'].gsub('_', '\_')}\n" +
        "*IP*: _#{data['IP']}_\n" +
        "*Статус*: _#{data['STATE']}_\n" +
        "*Ресурсы*:\n" +
        "    CPU: #{data['CPU']} cores\n" +
        "    RAM: #{data['RAM']}MB\n" +
        "    Диск: soon..\n" + 
        "    Типа диска: soon.."

        kb = [
            [
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Включить', callback_data: "/vm_resume #{vmid.to_s}"),
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Выключить', callback_data: "/vm_poweroff_sure #{vmid.to_s}"),
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Обновить', callback_data: "/vm_update #{vmid.to_s}")
            ],
            [
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Перезагрузить', callback_data: "/vm_reboot #{vmid.to_s}"),             
                Telegram::Bot::Types::InlineKeyboardButton.new(text: '⟲ Список ВМ', callback_data: "/vms")
            ],
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Открыть кабинет cloud', url: "vcloud.support.by")
        ]
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
        return message, markup
    end
    def vm(bot, msg)
        message, markup = vm_handler(bot, msg)
        bot.api.send_message(
            chat_id: msg.class.to_s.split('::').last == 'Message' ? msg.chat.id : msg.message.chat.id,
            text: message,
            reply_markup: markup,
            parse_mode: 'Markdown'
        )
    end
    def vm_update(bot, msg)
        message, markup = vm_handler(bot, msg)
        begin
            bot.api.edit_message_text(
                chat_id: msg.message.chat.id,
                message_id: msg.message.message_id,
                text: message,
                reply_markup: markup,
                parse_mode: 'Markdown'
            )
            bot.api.answer_callback_query(
                callback_query_id: msg.id,
                text: 'Данные обновлены...'
            )
        rescue => e
            bot.api.answer_callback_query(
                callback_query_id: msg.id,
                text: 'Ничего не изменилось...'
            )
        end
    end
    def help(bot, msg)
        kb = [
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Напишите нам в Telegram', url: 't.me/spby_bot'),
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Наш сайт', url: 'support.by'),
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Личный кабинет SPBY', url: 'my.support.by'),
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Личный кабинет Cloud SPBY', url: 'vcloud.support.by'),
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Страница проекта', url: 'ione-cloud.net'),
            Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Документация', url: 'docs.ione-cloud.net'),
            Telegram::Bot::Types::InlineKeyboardButton.new(text: '⟲ Назад', callback_data: '/menu')
        ]
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)        
        bot.api.send_message(
                chat_id: msg.chat.id,
                text: 'Вот что мы можем предложить:',
                reply_markup: markup
        )
    end
    def vms(bot, msg)
        message, markup = vms_handler(bot, msg)
        bot.api.send_message(
                chat_id: msg.chat.id,
                text: message,
                reply_markup: markup
        ) if msg.class.to_s == 'Telegram::Bot::Types::Message'
        bot.api.edit_message_text(
            chat_id: msg.message.chat.id,
            message_id: msg.message.message_id,
            text: message,
            reply_markup: markup
        ) if msg.class.to_s == 'Telegram::Bot::Types::CallbackQuery'
    end
    def vms_handler(bot, msg)
        begin
            uid, page = $ACCOUNTS[msg.from.username], msg.text.split(' ').last.to_i
        rescue
            uid, page = $ACCOUNTS[msg.from.username], msg.data.split(' ').last.to_i
        end
        if uid == 'none' then
            return 'You have not authorized or got no account in one', false
        else
            kb, user, message = [], onblock(:u, uid, $client), []
            user.info!
            token = user.login(user.name, '', 30)
            vp = VirtualMachinePool.new(Client.new("#{user.name}:#{token}"))
            vp.info_all!
            vp.each do | vm |
                if message.size >= page * 8 && message.size <= (page + 1) * 8 then
                    message << "#{vm.id.to_s}) #{vm.name}\n|#{space_gen((vm.id.to_s + ') ').size * 2)}#{IONe.new($client).GetIP(vm.id)}"
                    kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: vm.id.to_s, callback_data: "/vm #{vm.id.to_s}")
                else
                    message << nil
                    kb << nil
                end
            end
            if message.size > 8 then
                kb, size = kb[(page * 8)..(page * 8 + 8)], message.size
                kb.unshift(Telegram::Bot::Types::InlineKeyboardButton.new(text: '<<-', callback_data: "/vms 0")) if page == (size / 8)
                kb.unshift(Telegram::Bot::Types::InlineKeyboardButton.new(text: '<-', callback_data: "/vms #{page - 1}")) if page > 0
                kb.unshift(Telegram::Bot::Types::InlineKeyboardButton.new(text: ' ⟲ ', callback_data: "/menu"))
                kb.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: '->', callback_data: "/vms #{page + 1}")) if page < (size / 8)
                kb.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: '->>', callback_data: "/vms #{size / 8}")) if page == 0
                message = message[(page * 8)..(page * 8 + 8)]
                message.unshift("Ваши виртуальные машины:")
                message.push("\t\t\tСтраница: #{page}/#{(size / 8)}")
            end
            message = message.join("\n")
            markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: array_groupper(kb, 4))
            return message, markup
        end
    end


    def vm_resume(bot, msg)
        vmid = msg.data.split(' ').last.to_i
        onblock(:vm, vmid) do | vm |
            vm.resume
            iter = 0
            until vm.status == 'runn' || iter < 45 do
                vm.info! || sleep(1) || (iter += 1)
            end
        end
        vm_update(bot, msg)
    end

    def vm_poweroff_sure(bot, msg)
        bot.api.answer_callback_query(
            callback_query_id: msg.id,
            text: 'Загрузка...'
        )
        vmid = msg.data.split(' ').last.to_i    
        kb = [
            [
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Да', callback_data: "/vm_poweroff #{vmid.to_s}"),
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Нет', callback_data: "/vm_update #{vmid.to_s}")
            ]
        ]
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
        
        data = IONe.new($client).get_vm_data(vmid)
        message = 
        "Виртуальная машина *#{vmid.to_s}*\n\n" +
        "*Имя*: #{data['NAME']}\n" +
        "*IP*: _#{data['IP']}_\n" +
        "*Статус*: _#{data['STATE']}_\n" +
        "*Ресурсы*:\n" +
        "    CPU: #{data['CPU']} cores\n" +
        "    RAM: #{data['RAM']}MB\n" +
        "    Диск: soon..\n" + 
        "    Типа диска: soon.."
        message += "\n\n *Вы уверены?*"
        bot.api.edit_message_text(
            chat_id: msg.message.chat.id,
            message_id: msg.message.message_id,
            text: message,
            reply_markup: markup,
            parse_mode: 'Markdown'
        )
    end

    def vm_poweroff(bot, msg)
        vmid = msg.data.split(' ').last.to_i
        onblock(:vm, vmid) do | vm |
            vm.poweroff
            iter = 0
            bot.api.answer_callback_query(
                callback_query_id: msg.id,
                text: 'Выключение... Ждите обновлений'
            )
        end
        vm_update(bot, msg)
    end

    def vm_reboot_sure(bot, msg)
        bot.api.answer_callback_query(
            callback_query_id: msg.id,
            text: 'Загрузка...'
        )
        vmid = msg.data.split(' ').last.to_i    
        kb = [
            [
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Да', callback_data: "/vm_reboot #{vmid.to_s}"),
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Нет', callback_data: "/vm_update #{vmid.to_s}")
            ]
        ]
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
        
        data = IONe.new($client).get_vm_data(vmid)
        message = 
        "Виртуальная машина *#{vmid.to_s}*\n\n" +
        "*Имя*: #{data['NAME']}\n" +
        "*IP*: _#{data['IP']}_\n" +
        "*Статус*: _#{data['STATE']}_\n" +
        "*Ресурсы*:\n" +
        "    CPU: #{data['CPU']} cores\n" +
        "    RAM: #{data['RAM']}MB\n" +
        "    Диск: soon..\n" + 
        "    Типа диска: soon.."
        message += "\n\n *Вы уверены?*"
        bot.api.edit_message_text(
            chat_id: msg.message.chat.id,
            message_id: msg.message.message_id,
            text: message,
            reply_markup: markup,
            parse_mode: 'Markdown'
        )
    end

    def vm_reboot(bot, msg)
        vmid = msg.data.split(' ').last.to_i
        onblock(:vm, vmid) do | vm |
            vm.reboot
            iter = 0
            bot.api.answer_callback_query(
                callback_query_id: msg.id,
                text: 'Перезагрузка... Ждите обновлений'
            )
        end
        vm_update(bot, msg)
    end
end

def array_groupper(arr, div)
    res = []
    for i in 0..(arr.size - 1) do
        res[i / div] = [] if i % div == 0 
        res[i / div] << arr[i]
    end
    return res
end