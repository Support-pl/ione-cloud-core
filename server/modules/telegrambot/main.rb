token = '559508786:AAFihmxUyncrdBarA_fQyIpyLJl9o0Z5gDE'
ROOT = ENV['IONEROOT']

require 'telegram/bot'
require "#{ROOT}/modules/telegrambot/auth.rb"
require "#{ROOT}/modules/telegrambot/lang.rb"
require "#{ROOT}/modules/telegrambot/keyboards.rb"

$key1 = $key2 = false

Telegram::Bot::Client.run(token) do |bot|
    bot.listen do |msg|
        if msg.text == '/start' || msg.text == 'Log out' then
            bot.api.send_message(
                chat_id: msg.chat.id,
                text: Hello.message(lang(msg.from.username)),
                reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                    keyboard: Hello.markup(lang(msg.from.username)), one_time_keyboard: true
                )
            )
        elsif msg.text == 'Authentificate' then
            bot.api.send_message(
                chat_id: msg.chat.id,
                text: Auth.message(lang(msg.from.username)),
                reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                    keyboard: Auth.markup(lang(msg.from.username)), one_time_keyboard: true
                )
            )
        elsif msg.text == '/kill' then
            $key1 = $key1
            Kernel.exit if $key1 && $key2
        elsif msg.text == '/now' then
            $key2 = !$key2
            Kernel.exit if $key1 && $key2
        
        # Phone authentification driver
        elsif msg.contact != nil then
            puts msg.contact.phone_number
            puts generate_code(msg.contact.phone_number)
            add_number(msg.from.username, msg.contact.phone_number)
            bot.api.send_message(
                chat_id: msg.chat.id,
                text: 'Type here the code from SMS, using command: /code <your-code>'
            )
        elsif msg.text == '⟲Back' then
            bot.api.send_message(
                chat_id: msg.chat.id,
                text: Hello.message(lang(msg.from.username)),
                reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                    keyboard: Hello.markup(lang(msg.from.username)), one_time_keyboard: true
                )
            )
        elsif msg.text == '/codes' then
            bot.api.send_message(
                chat_id: msg.chat.id,
                text: $codes.to_s
            )
        elsif msg.text.split(' ').first == '/code' then
            auth = auth_by_number(msg.from.username, get_number(msg.from.username), msg.text.split(' ').last)
            if auth then
                bot.api.send_message(
                    chat_id: msg.chat.id,
                    text: UserArea.message(lang(msg.from.username)),
                    reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                        keyboard: UserArea.markup(lang(msg.from.username)), one_time_keyboard: true
                    )
                )
            else
                bot.api.send_message(
                    chat_id: msg.chat.id,
                    text: AuthFail.message(lang(msg.from.username)),
                    reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                        keyboard: AuthFail.markup(lang(msg.from.username)), one_time_keyboard: true
                    )
                )
            end
        elsif msg.text == 'Language' then
            bot.api.send_message(
                chat_id: msg.chat.id,
                text: Lang.message(lang(msg.from.username)),
                reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                    keyboard: Lang.markup(lang(msg.from.username)), one_time_keyboard: true
                )
            )
        elsif languages().include? msg.text.to_sym then
            set_lang(msg.from.username, msg.text.to_sym)
            bot.api.send_message(
                chat_id: msg.chat.id,
                text: Hello.message(lang(msg.from.username)),
                reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
                    keyboard: Hello.markup(lang(msg.from.username)), one_time_keyboard: true
                )
            )
        else
            begin
                puts msg.text
            rescue
            end
        end
      end
  end