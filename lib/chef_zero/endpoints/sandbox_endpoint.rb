require "chef_zero/rest_base"
require "chef_zero/rest_error_response"
require "ffi_yajl"

module ChefZero
  module Endpoints
    # /sandboxes/ID
    class SandboxEndpoint < RestBase
      def put(request)
        existing_sandbox = FFI_Yajl::Parser.parse(get_data(request))
        existing_sandbox["checksums"].each do |checksum|
          if !exists_data?(request, request.rest_path[0..1] + ["file_store", "checksums", checksum])
            raise RestErrorResponse.new(503, "Checksum not uploaded: #{checksum}")
          end
        end
        delete_data(request)
        json_response(200, {
          :guid => request.rest_path[3],
          :name => request.rest_path[3],
          :checksums => existing_sandbox["checksums"],
          :create_time => existing_sandbox["create_time"],
          :is_completed => true,
        })
      end
    end
  end
end
