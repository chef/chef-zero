module ChefZero
  class Router
    def initialize(routes)
      @routes = routes.map do |route, endpoint|
        pattern = Regexp.new("^#{route.gsub('*', '[^/]*')}$")
        [ pattern, endpoint ]
      end
    end

    attr_reader :routes
    attr_accessor :not_found

    def call(env)
      puts "#{env['REQUEST_METHOD']} #{env['PATH_INFO']}#{env['QUERY_STRING'] != '' ? "?" + env['QUERY_STRING'] : ''}"
      clean_path = "/" + env['PATH_INFO'].split('/').select { |part| part != "" }.join("/")
      routes.each do |route, endpoint|
        if route.match(clean_path)
          return endpoint.call(env)
        end
      end
      not_found.call(env)
    end
  end
end
