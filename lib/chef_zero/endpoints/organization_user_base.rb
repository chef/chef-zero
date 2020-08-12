require "ffi_yajl" unless defined?(FFI_Yajl)
require_relative "../rest_base"

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
