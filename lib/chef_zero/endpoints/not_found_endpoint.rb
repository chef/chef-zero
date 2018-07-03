require "ffi_yajl"

module ChefZero
  module Endpoints
    class NotFoundEndpoint
      def call(request)
        [404, { "Content-Type" => "application/json" }, FFI_Yajl::Encoder.encode({ "error" => ["Object not found: #{request.env['REQUEST_PATH']}"] }, pretty: true)]
      end
    end
  end
end
