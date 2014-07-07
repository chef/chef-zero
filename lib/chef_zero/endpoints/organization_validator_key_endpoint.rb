require 'json'
require 'chef_zero/rest_base'
require 'uuidtools'

module ChefZero
  module Endpoints
    # /organizations/NAME/_validator_key
    class OrganizationValidatorKeyEndpoint < RestBase
      def post(request)
        org_name = request.rest_path[-2]
        validator_path = [ 'organizations', org_name, 'clients', "#{org_name}-validator"]
        validator = JSON.parse(get_data(request, validator_path), :create_additions => false)
        private_key, public_key = server.gen_key_pair
        validator['public_key'] = public_key
        set_data(request, validator_path, JSON.pretty_generate(validator))
        json_response(200, { 'private_key' => private_key })
      end
    end
  end
end
