# Installing system libs, tools and gems

echo "Attention: make, automake, gcc, gcc-c++, kernel-devel, ruby-devel, zeromq, zeromq-devel libs and zmqjsonrpc gem will be installed."

#echo -n "You have 5 sec before some dangerous stuff will started..."
#echo -n '5..' && sleep 1 && echo -n '4..' && sleep 1 && echo -n '3..' && sleep 1 && echo -n '2..' && sleep 1 && echo -n '1..' && sleep 1 && echo 'Go'

sed -i 's/enabled\=1/enabled\=0/g'  /etc/yum.repos.d/opennebula.repo
sed -i 's/enabled\=1/enabled\=0/g'  /etc/yum.repos.d/vonecloud.repo
yum install -y git make automake gcc gcc-c++ kernel-devel ruby-devel zeromq zeromq-devel
gem install zmqjsonrpc
sed -i 's/enabled\=0/enabled\=1/g'  /etc/yum.repos.d/opennebula.repo
sed -i 's/enabled\=0/enabled\=1/g'  /etc/yum.repos.d/vonecloud.repo

# Creating gem-test file

echo "require 'zmqjsonrpc'

class TestHand
    def test_func(msg)
        return 'pong' if msg == 'ping'
    end
end

server = ZmqJsonRpc::Server.new(TestHand.new, 'tcp://*:666666')
Thread.new do
    server.server_loop
end

client = ZmqJsonRpc::Client.new('tcp://localhost:666666')
if client.test_func('ping') == 'pong' then
    puts 'OK'
else
    puts 'FAIL'
end" > gemtest.rb

# Testing how the lib was installed

UNIT=`/usr/bin/ruby gemtest.rb`

if [ "$UNIT" == 'OK' ]; then
    echo '++++++++++++++++++++++++++++++++++++++++++++++'
    echo '+    Deploy process finished successfuly!    +'
    echo '++++++++++++++++++++++++++++++++++++++++++++++'
else
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "+ Something went wrong, it's maybe caused by 'zmqjsonrpc' gem installing... +"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
fi

git clone --branch stable https://github.com/ione-cloud/ione-cloud-core.git
mv ione-cloud-core ione-cloud
cd ione-cloud

cp -f utils/ione /usr/bin
chmod +x /usr/bin/ione

DIR=`pwd`

echo >> ~/.bashrc
echo "export IONEROOT=\"$DIR/server\"" >> ~/.bashrc
echo 'export IONELOGROOT="/var/log/ione"' >> ~/.bashrc
systemctl set-environment IONEROOT=$IONEROOT
systemctl set-environment IONEROOT=$IONELOGROOT

cp -f utils/ione.service /lib/systemd/system/ione.service
systemctl daemon-reload

mkdir /var/log/ione

rm -f ./gemtest.rb
rm -f ./deploy.sh
rm -f .gitignore
