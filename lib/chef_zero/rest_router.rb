require 'chef/log'

module ChefZero
  class RestRouter
    def initialize(routes)
      @routes = routes.map do |route, endpoint|
        pattern = Regexp.new("^#{route.gsub('*', '[^/]*')}$")
        [ pattern, endpoint ]
      end
    end

    attr_reader :routes
    attr_accessor :not_found

    def call(request)
      begin
        Chef::Log.debug "Request: #{request}"
        clean_path = "/" + request.rest_path.join("/")
        routes.each do |route, endpoint|
          if route.match(clean_path)
            return endpoint.call(request)
          end
        end
        not_found.call(request)
      rescue
        Chef::Log.error("#{$!.inspect}\n#{$!.backtrace.join("\n")}")
        [500, {"Content-Type" => "text/plain"}, "Exception raised!  #{$!.inspect}\n#{$!.backtrace.join("\n")}"]
      end
    end
  end
end
