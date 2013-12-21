module Rbsh
  class IdGenerator
    def initialize
      @recycle = []
      @max_outstanding = 0
    end

    def get
      if @recycle.empty?
        @max_outstanding += 1
        @max_outstanding
      else
        @recycle.shift
      end  
    end

    def recycle(id)
      @recycle.push id
      @recycle.sort!
    end
  end
end
