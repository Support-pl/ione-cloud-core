class IONe
    def IONeUpdate(token, trace = ["Update Process starter:#{__LINE__}"])
        return 'Wrong token!' if token != CONF['UpdatesManager']['update-token']
        begin
            trace << "Creating temporary dir:#{__LINE__ + 1}"
            `mkdir /tmp/ione`

            trace << "Cloning git repository to temporary dir:#{__LINE__ + 1}"
            `git clone --branch #{CONF['UpdatesManager']['branch']} #{CONF['UpdatesManager']['repo']} /tmp/ione`

            trace << "Replacing the old server:#{__LINE__ + 1}"
            `cp -rf /tmp/ione/server/* #{ROOT}/`

            "Starting bundler:#{__LINE__ + 1}"
            `bundle install --gemfile /tmp/ione/Gemfile`

            trace << "Replacing cli utility:#{__LINE__ + 1}"
            `cp /tmp/ione/utils/ione /usr/bin`
            `chmod +x /usr/bin/ione`


            trace << "Replacing systemd service:#{__LINE__ + 1}"
            `mv /tmp/ione/utils/ione.service /lib/systemd/system/ione.service`
            `systemctl daemon-reload`
            
            trace << "Cleaning temporary dir:#{__LINE__ + 1}"
            `rm -rf /tmp/ione`
            `rm -rf #{ROOT}/../utils`

            return "Update successful, current version: #{File.read("#{ROOT}/meta/version.txt").chomp}"
        rescue => e
            return e.message, trace
        end
    end
end