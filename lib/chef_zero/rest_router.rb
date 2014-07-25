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
      begin
        ChefZero::Log.debug(request)
        ChefZero::Log.debug(request.body) if request.body

        clean_path = "/" + request.rest_path.join("/")

        response = find_endpoint(clean_path).call(request)
        ChefZero::Log.debug([
          "",
          "--- RESPONSE (#{response[0]}) ---",
          response[2],
          "--- END RESPONSE ---",
        ].join("\n"))
        return response
      rescue
        ChefZero::Log.error("#{$!.inspect}\n#{$!.backtrace.join("\n")}")
        [500, {"Content-Type" => "text/plain"}, "Exception raised!  #{$!.inspect}\n#{$!.backtrace.join("\n")}"]
      end
    end

    private

      def find_endpoint(clean_path)
        _, endpoint = routes.find { |route, endpoint| route.match(clean_path) }
        endpoint || not_found
      end
  end
end
