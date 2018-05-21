require 'mysql2'

$client = Mysql2::Client.new(
    :username => 'root', :password => 'opennebula', 
    :host => 'localhost', :database => 'tgusers' )

# CREATE TABLE user (username VARCHAR(255), phonenumber VARCHAR(16), one_user INTEGER)

def write_user(username, phone, userid)
    $db.query("INSERT INTO user (username, phone, one_user) VALUES ('#{username}', '#{phone}', '#{userid}')")
end