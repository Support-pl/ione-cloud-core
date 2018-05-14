class Answer
    def initialize(message, markup)
        @message, @markup = message, markup
    end
    def message(lang = :en)
        @message[lang]
    end
    def markup(lang = :en)
        @markup[lang] if @markup.class == Hash
        @markup if @markup.class == Array
    end
end

Hello = Answer.new(
    {:en => "Hello, i'm IONe Bot, how can i call you?", :ru => 'Привет, я IONe Бот, как я могу тебя звать?'},
    {:en => [ 'Authentificate', 'Register', 'Language' ], :ru => ['Аутентификация', 'Регистрация', 'Язык']}
)

Auth = Answer.new(
    {:en => "Choose auth method:", :ru => 'Выбери метод аутентификации:'},
    {
        :en => [ 
            Telegram::Bot::Types::KeyboardButton.new(
                text: 'by Phone Number', request_contact: true
            ),
            'by Support.by Account', '⟲ Back'
        ],
        :ru => [ 
            Telegram::Bot::Types::KeyboardButton.new(
                text: 'по Номеру Телефона', request_contact: true
            ),
            'по аккаунту в Support.by', '⟲ Назад'
        ]
    }
)

AuthFail = Answer.new(
    {:en => 'Authentification fail, try again...', :ru => 'Ошибка аутентификации, попробуй еще раз...'},
    Hello.markup
)

UserArea = Answer.new(
    {:en => "Here is you area, have fun!"},
    [
        ['VM', 'Resources', 'Settings'], ['Order new', 'Log out']
    ]
)

Lang = Answer.new(
    {:en => "Choose your language:", :ru => "Выбери свой язык"},
    languages()
)