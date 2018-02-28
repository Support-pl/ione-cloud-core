class CacheStack
    
    include Enumerable
  
    def initialize(num = 5)
      @size = num
      @queue = Array.new
    end
    def each(&blk)
      @queue.each(&blk)
    end
    def pop
      @queue.pop
    end
    def push(value)
      @queue.shift if @queue.size >= @size
      @queue.push(value)
    end
    def to_a
      @queue.to_a
    end
    def <<(value)
      push(value)
    end
    def last
        return @queue.last
    end
    def get_if_include(data)
        return (self << @queue.delete(data)).last
    end
    def to_s
        return @queue
    end
    
end 