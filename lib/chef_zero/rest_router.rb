require "pp"

module ChefZero
  class RestRouter
    def initialize(routes)
      @routes = routes.map do |route, endpoint|
        if route =~ /\*\*$/
          pattern = Regexp.new("^#{route[0..-3].gsub('*', '[^/]*')}")
        else
          pattern = Regexp.new("^#{route.gsub('*', '[^/]*')}$")
        end
        [ pattern, endpoint ]
      end
    end

    attr_reader :routes
    attr_accessor :not_found

    def call(request)
      log_request(request)

      clean_path = "/" + request.rest_path.join("/")

      find_endpoint(clean_path).call(request).tap do |response|
        log_response(response)
      end
    rescue => ex
      exception = "#{ex.inspect}\n#{ex.backtrace.join("\n")}"

      ChefZero::Log.error(exception)
      [ 500, { "Content-Type" => "text/plain" }, "Exception raised! #{exception}" ]
    end

    private

    def find_endpoint(clean_path)
      _, endpoint = routes.find { |route, endpoint| route.match(clean_path) }
      endpoint || not_found
    end

    def log_request(request)
      ChefZero::Log.debug do
        "#{request.method} /#{request.rest_path.join("/")}".tap do |msg|
          next unless request.method =~ /^(POST|PUT)$/

          if request.body.nil? || request.body.empty?
            msg << " (no body)"
          else
            msg << [
              "",
              "--- #{request.method} BODY ---",
              request.body.chomp,
              "--- END #{request.method} BODY ---",
            ].join("\n")
          end
        end
      end

      ChefZero::Log.debug { request.pretty_inspect }
    end

    def log_response(response)
      ChefZero::Log.debug do
        [ "",
          "--- RESPONSE (#{response[0]}) ---",
          response[2].chomp,
          "--- END RESPONSE ---",
        ].join("\n")
      end
    end
  end
end
