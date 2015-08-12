require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    module OrganizationUserBase

      def self.get(obj, request, &block)
        result = obj.list_data(request).map(&block)
        obj.json_response(200, result)
      end

      def self.post(obj, request, key)
        json = FFI_Yajl::Parser.parse(request.body, :create_additions => false)
        username = json[key]
        orgname = request.rest_path[1]
        id = "#{username}-#{orgname}"

        if obj.exists_data?(request, [ 'organizations', orgname, 'users', username ])
          raise RestErrorResponse.new(409, "User #{username} is already in organization #{orgname}")
        end

        obj.create_data(request, request.rest_path, username, '{}')
        obj.json_response(201, { "uri" => obj.build_uri(request.base_uri, request.rest_path + [ id ]) })
      end

    end
  end
end
