require 'json'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /organizations/ORG/containers
    class ContainersEndpoint < RestListEndpoint
      def initialize(server)
        super(server, 'containername')
      end
    end
  end
end
