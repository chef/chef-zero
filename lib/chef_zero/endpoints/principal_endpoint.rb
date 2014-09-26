require 'ffi_yajl'
require 'chef_zero'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /principals/NAME
    class PrincipalEndpoint < RestBase
      def get(request)
        name = request.rest_path[-1]
        json = get_data(request, request.rest_path[0..1] + [ 'users', name ], :nil)
        if json
          type = 'user'
          org_member = true
        else
          json = get_data(request, request.rest_path[0..1] + [ 'clients', name ], :nil)
          if json
            type = 'client'
            org_member = true
          else
            json = get_data(request, [ 'users', name ], :nil)
            if json
              type = 'user'
              org_member = false
            end
          end
        end
        if json
          json_response(200, {
            'name' => name,
            'type' => type,
            'public_key' => FFI_Yajl::Parser.parse(json)['public_key'] || PUBLIC_KEY,
            'authz_id' => '0'*32,
            'org_member' => org_member
          })
        else
          error(404, 'Principal not found')
        end
      end
    end
  end
end
