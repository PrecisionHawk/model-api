module ModelApi
  class NotFoundException < Exception
    attr_reader :field

    def initialize(field = nil, message = nil)
      super(message)
      @field = field
    end
  end
end
