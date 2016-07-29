require "ffi_yajl"
require "chef_zero/endpoints/rest_list_endpoint"

module ChefZero
  module Endpoints
    # /users, /organizations/ORG/clients or /organizations/ORG/users
    class ActorsEndpoint < RestListEndpoint
      def get(request)
        response = super(request)

        # apply query filters: if one applies, stop processing rest
        # (precendence matches chef-server: https://github.com/chef/chef-server/blob/268a0c9/src/oc_erchef/apps/chef_objects/src/chef_user.erl#L554-L559)
        if value = request.query_params["external_authentication_uid"]
          response[2] = filter("external_authentication_uid", value, request, response[2])
        elsif value = request.query_params["email"]
          response[2] = filter("email", value, request, response[2])
        end

        if request.query_params["verbose"]
          results = parse_json(response[2])
          results.each do |name, url|
            record = get_data(request, request.rest_path + [ name ], :nil)
            if record
              record = parse_json(record)
              record = ChefData::DataNormalizer.normalize_user(record, name, identity_keys, server.options[:osc_compat])
              results[name] = record
            end
          end
          response[2] = to_json(results)
        end
        response
      end

      def post(request)
        # First, find out if the user actually posted a public key.  If not, make
        # one.
        request_body = parse_json(request.body)
        public_key = request_body["public_key"]

        skip_key_create = !request.api_v0? && !request_body["create_key"]

        if !public_key && !skip_key_create
          private_key, public_key = server.gen_key_pair
          request_body["public_key"] = public_key
          request.body = to_json(request_body)
        elsif skip_key_create
          request_body["public_key"] = nil
          request.body = to_json(request_body)
        end

        result = super(request)

        if result[0] == 201
          # If we generated a key, stuff it in the response.
          user_data = parse_json(result[2])

          key_data = {}
          key_data["private_key"] = private_key if private_key
          key_data["public_key"] = public_key unless request.rest_path[0] == "users"

          response =
            if request.api_v0?
              user_data.merge!(key_data)
            elsif skip_key_create && !public_key
              user_data
            else
              actor_name = request_body["name"] || request_body["username"] || request_body["clientname"]

              relpath_to_default_key = [ actor_name, "keys", "default" ]
              key_data["uri"] = build_uri(request.base_uri, request.rest_path + relpath_to_default_key)
              key_data["public_key"] = public_key
              key_data["name"] = "default"
              key_data["expiration_date"] = "infinity"
              user_data["chef_key"] = key_data
              user_data
            end

          json_response(201, response)
        else
          result
        end
      end

      private

      def filter(key, value, request, resp)
        results = parse_json(resp)
        new_results = {}
        results.each do |name, url|
          record = get_data(request, request.rest_path + [ name ], :nil)
          if record
            record = parse_json(record)
            new_results[name] = url if record[key] == value
          end
        end
        to_json(new_results)
      end
    end
  end
end
