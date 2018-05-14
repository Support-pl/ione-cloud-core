Languages = [:en, :ru]

def languages
    return Languages
end

def lang(username = nil)
    # searhching user at DB
    return $users[username][:lang] || :en
end

def set_lang(username, lang)
    $users[username][:lang] = lang
end