require "ffi_yajl"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    module OrganizationUserBase

      def self.get(obj, request, &block)
        result = obj.list_data(request).map(&block)
        obj.json_response(200, result)
      end

    end
  end
end
