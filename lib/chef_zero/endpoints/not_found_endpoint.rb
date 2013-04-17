require 'json'

module ChefZero
  module Endpoints
    class NotFoundEndpoint
      def call(request)
        return [404, {"Content-Type" => "application/json"}, JSON.pretty_generate({"error" => ["Object not found: #{request.env['REQUEST_PATH']}"]})]
      end
    end
  end
end
