require 'ffi_yajl'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /policies/:group/:name
    class PoliciesEndpoint < RestObjectEndpoint
      def initialize(server)
        super(server, 'id')
      end

      def get(request)
        already_json_response(200, get_data(request))
      end

      # Right now we're allowing PUT to create.
      def put(request)
        error = validate(request)
        return error if error

        code = create_or_update(request)
        already_json_response(code, request.body)
      end

      def delete(request)
        result = get_data(request, request.rest_path)
        delete_data(request, request.rest_path, :data_store_exceptions)
        already_json_response(200, result)
      end

      def create_or_update(request)
        set_data(request, request.rest_path, request.body, :data_store_exceptions)
        200
      rescue ChefZero::DataStore::DataNotFoundError
        name = request.rest_path[4]
        data_store.create(request.rest_path[0..3], name, request.body, :create_dir)
        201
      end

      private

      def validate(request)
        req_object = validate_json(request.body)
        validate_name(request, req_object) ||
          validate_run_list(req_object) ||
          validate_each_run_list_item(req_object) ||
          validate_cookbook_locks_collection(req_object) ||
          validate_each_cookbook_locks_item(req_object)
      end

      def validate_json(request_body)
        FFI_Yajl::Parser.parse(request_body)
        # TODO: rescue parse error, return 400
        # error(400, "Must specify #{identity_keys.map { |k| k.inspect }.join(' or ')} in JSON")
      end

      def validate_name(request, req_object)
        if !req_object.key?("name")
          error(400, "Must specify 'name' in JSON")
        elsif req_object["name"] != URI.decode(request.rest_path[4])
          error(400, "'name' field in JSON must match the policy name in the URL")
        elsif req_object["name"].size > 255
          error(400, "'name' field in JSON must be 255 characters or fewer")
        elsif req_object["name"] !~ /^[\-[:alnum:]_\.\:]+$/
          error(400, "'name' field in JSON must be contain only alphanumeric, hypen, underscore, and dot characters")
        end
      end

      def validate_run_list(req_object)
        if !req_object.key?("run_list")
          error(400, "Must specify 'run_list' in JSON")
        elsif !req_object["run_list"].kind_of?(Array)
          error(400, "'run_list' must be an Array of run list items")
        end
      end

      def validate_each_run_list_item(req_object)
        req_object["run_list"].each do |run_list_item|
          if res_400 = validate_run_list_item(run_list_item)
            return res_400
          end
        end
        nil
      end

      def validate_run_list_item(run_list_item)
        if !run_list_item.kind_of?(String)
          error(400, "Items in run_list must be strings in fully qualified recipe format, like recipe[cookbook::recipe]")
        elsif run_list_item !~ /\Arecipe\[[^\s]+::[^\s]+\]\Z/
          error(400, "Items in run_list must be strings in fully qualified recipe format, like recipe[cookbook::recipe]")
        end
      end

      def validate_cookbook_locks_collection(req_object)
        if !req_object.key?("cookbook_locks")
          error(400, "Must specify 'cookbook_locks' in JSON")
        elsif !req_object["cookbook_locks"].kind_of?(Hash)
          error(400, "'cookbook_locks' must be a JSON object of cookbook_name: lock_data pairs")
        end
      end

      def validate_each_cookbook_locks_item(req_object)
        req_object["cookbook_locks"].each do |cookbook_name, lock|
          if res_400 = validate_cookbook_locks_item(cookbook_name, lock)
            return res_400
          end
        end
        nil
      end

      def validate_cookbook_locks_item(cookbook_name, lock)
        if !lock.kind_of?(Hash)
          error(400, "cookbook_lock entries must be a JSON object")
        elsif !lock.key?("identifier")
          error(400, "cookbook_lock entries must contain an 'identifier' field")
        elsif !lock.key?("dotted_decimal_identifier")
          error(400, "cookbook_lock entries must contain an 'dotted_decimal_identifier' field")
        elsif lock["identifier"].size > 255
          error(400, "cookbook_lock entries 'identifier' field must be 255 or fewer characters")
        end
      end

    end
  end
end

