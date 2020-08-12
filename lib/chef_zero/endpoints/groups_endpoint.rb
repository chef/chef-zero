require "ffi_yajl" unless defined?(FFI_Yajl)
require_relative "rest_list_endpoint"

module ChefZero
  module Endpoints
    # /organizations/ORG/groups/NAME
    class GroupsEndpoint < RestListEndpoint
      def initialize(server)
        super(server, %w{id groupname})
      end
    end
  end
end
