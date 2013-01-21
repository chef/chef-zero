require 'rack/request'

module ChefZero
  class RestRequest
    def initialize(env)
      @env = env
    end

    attr_reader :env

    def base_uri
      @base_uri ||= "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{env['SCRIPT_NAME']}"
    end

    def method
      @env['REQUEST_METHOD']
    end

    def rest_path
      @rest_path ||= env['PATH_INFO'].split('/').select { |part| part != "" }
    end

    def body=(body)
      @body = body
    end

    def body
      @body ||= env['rack.input'].read
    end

    def query_params
      @query_params ||= begin
        params = Rack::Request.new(env).GET
        params.keys.each do |key|
          params[key] = URI.unescape(params[key])
        end
        params
      end
    end

    def to_s
      result = "#{method} #{rest_path.join('/')}"
      if query_params.size > 0
        result << "?#{query_params.map { |k,v| "#{k}=#{v}" }.join('&') }"
      end
      if body.chomp != ''
        result << "\n--- #{method} BODY ---\n"
        result << body
        result << "\n" if !body.end_with?("\n")
        result << "--- END #{method} BODY ---"
      end
      result
    end
  end
end

