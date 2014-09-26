require 'ffi_yajl'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /organizations/ORG/containers
    class ContainersEndpoint < RestListEndpoint
      def initialize(server)
        super(server, %w(id containername))
      end
    end
  end
end
