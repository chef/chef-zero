require 'json'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /organizations/ORG/groups/NAME
    class GroupsEndpoint < RestListEndpoint
      def initialize(server)
        super(server, 'groupname')
      end
    end
  end
end
