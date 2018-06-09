require 'json'
require 'digest/md5'

puts 'Extending Hash class by out method'
# Ruby default Hash class
class Hash
    # Returns hash as 'pretty generated' JSON String
    def out()
        JSON.pretty_generate(self)
    end
    # Returns hash as 'pretty generated' JSON String with replaced JSON(':' to '=>' and 'null' to 'nil')
    def debug_out()
        JSON.pretty_generate(self).gsub("\": ", "\" => ").gsub(" => null", " => nil")
    end
    # @!visibility private
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
        result
    end
    # Replaces string key to symbols
    # @return [Hash]
    def to_sym!
        self.keys.each do |key| 
            self[key.to_sym] = self.delete key if key.class == String
        end
        self
    end
end

# Ruby default String class
class String
    # @!visibility private    
    def private?
        result = false
        for key in CONF['PrivateKeys'] do
            result = result || self.include?(key)
        end
        result
    end
end


puts 'Extending NilClass by add method'
# Ruby default Nil class
class NilClass
    # @!visibility private    
    def +(obj)
        obj
    end
end