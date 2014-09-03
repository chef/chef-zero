require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # The minimum amount of S3 necessary to support cookbook upload/download
    # /organizations/NAME/file_store/FILE
    class FileStoreFileEndpoint < RestBase
      def json_only
        false
      end

      def get(request)
        [200, {"Content-Type" => 'application/x-binary'}, get_data(request) ]
      end

      def put(request)
        data_store.set(request.rest_path, request.body, :create, :create_dir, :requestor => request.requestor)
        json_response(200, {})
      end
    end
  end
end
