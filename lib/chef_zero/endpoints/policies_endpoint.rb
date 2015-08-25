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

        code =
          if data_store.exists?(request.rest_path)
            set_data(request, request.rest_path, request.body, :data_store_exceptions)
            200
          else
            name = request.rest_path[4]
            data_store.create(request.rest_path[0..3], name, request.body, :create_dir)
            201
          end
        already_json_response(code, request.body)
      end

      def delete(request)
        result = get_data(request, request.rest_path)
        delete_data(request, request.rest_path, :data_store_exceptions)
        already_json_response(200, result)
      end

      private

      def validate(request)
        req_object = validate_json(request.body)
        validate_revision_id(request, req_object) ||
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

      def validate_revision_id(request, req_object)
        if !req_object.key?("revision_id")
          error(400, "Field 'revision_id' missing")
        elsif req_object["revision_id"].empty?
          error(400, "Field 'revision_id' invalid")
        elsif req_object["revision_id"].size > 255
          error(400, "Field 'revision_id' invalid")
        elsif req_object["revision_id"] !~ /^[\-[:alnum:]_\.\:]+$/
          error(400, "Field 'revision_id' invalid")
        end
      end

      def validate_name(request, req_object)
        if !req_object.key?("name")
          error(400, "Field 'name' missing")
        elsif req_object["name"] != (uri_policy_name = URI.decode(request.rest_path[4]))
          error(400, "Field 'name' invalid : #{uri_policy_name} does not match #{req_object["name"]}")
        elsif req_object["name"].size > 255
          error(400, "Field 'name' invalid")
        elsif req_object["name"] !~ /^[\-[:alnum:]_\.\:]+$/
          error(400, "Field 'name' invalid")
        end
      end

      def validate_run_list(req_object)
        if !req_object.key?("run_list")
          error(400, "Field 'run_list' missing")
        elsif !req_object["run_list"].kind_of?(Array)
          error(400, "Field 'run_list' is not a valid run list")
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
          error(400, "Field 'run_list' is not a valid run list")
        elsif run_list_item !~ /\Arecipe\[[^\s]+::[^\s]+\]\Z/
          error(400, "Field 'run_list' is not a valid run list")
        end
      end

      def validate_cookbook_locks_collection(req_object)
        if !req_object.key?("cookbook_locks")
          error(400, "Field 'cookbook_locks' missing")
        elsif !req_object["cookbook_locks"].kind_of?(Hash)
          error(400, "Field 'cookbook_locks' invalid")
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
          error(400, "Field 'identifier' missing")
        elsif lock["identifier"].size > 255
          error(400, "Field 'identifier' invalid")
        elsif !lock.key?("version")
          error(400, "Field 'version' missing")
        elsif lock.key?("dotted_decimal_identifier")
          unless valid_version?(lock["dotted_decimal_identifier"])
            error(400, "Field 'dotted_decimal_identifier' is not a valid version")
          end
        end
      end

      def valid_version?(version_string)
        Gem::Version.new(version_string)
        true
      rescue ArgumentError
        false
      end

    end
  end
end

