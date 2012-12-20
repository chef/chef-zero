module ChefZero
  module Endpoints
    class NotFoundEndpoint
      def call(env)
        return [404, {"Content-Type" => "application/json"}, "Object not found: #{env['REQUEST_PATH']}"]
      end
    end
  end
end
