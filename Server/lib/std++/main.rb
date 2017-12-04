require 'json'
require 'digest/md5'

class Hash
    def out
        return JSON.pretty_generate(self).gsub("\": ", "\" => ")
    end
    def privatise
        result = {}
        self.each do |key, value|
            if value.class == Hash then
                result[key] = value.privatise
                next
            elsif key.private? then
                result[key] = Digest::MD5.hexdigest(Digest::MD5.hexdigest(Digest::MD5.hexdigest(value.to_s)))
            else
                result[key] = value
            end
        end
        return result
    end
end

class String
    def private?
        result = false
        for key in CONF['PrivateKeys'] do
            result = result || self.include?(key)
        end
        return result
    end
end