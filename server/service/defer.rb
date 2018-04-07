module Deferable
    def defer &block
        @defered_methods << block
        return true
    end

    def self.included(mod)
        mod.extend ClassMethods
    end

    module ClassMethods
        def deferable method
            original_method = instance_method(method)
            define_method(method) do |*args|
                @@defered_method_stack ||= []
                @@defered_method_stack << @defered_methods
                @defered_methods = []
                begin
                    original_method.bind(self).(*args)
                ensure
                    @defered_methods.each {|m| m.call }
                    @defered_methods = @@defered_method_stack.pop
                end
            end
        end
    end
end
