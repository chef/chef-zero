module ChefZero
  class RestErrorResponse < StandardError
    attr_reader :response_code, :error

    def initialize(response_code, error)
      @response_code = response_code
      @error = error
      super "#{response_code}: #{error}"
    end
  end
end
