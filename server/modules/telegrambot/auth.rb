$codes = {}
$numbers = {}
$users = Hash.new({:lang => :en})

def auth_by_number(username, number, code)
    if $codes[number] == code
        return $users[username][:auth] = true
    end
    return false
end

def generate_code(number)
    $codes[number] = rand(10000..99999).to_s
end

def add_number(username, number)
    $numbers[username] = number
end

def get_number(username)
    return $numbers[username]
end