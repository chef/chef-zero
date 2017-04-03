require "ffi_yajl"
require "chef_zero/endpoints/rest_object_endpoint"
require "chef_zero/rest_error_response"
require "chef_zero/chef_data/data_normalizer"
require "chef_zero/data_store/data_not_found_error"

module ChefZero
  module Endpoints
    # /organizations/ORG/cookbooks/NAME/VERSION
    class CookbookVersionEndpoint < RestObjectEndpoint
      def get(request)
        if request.rest_path[4] == "_latest" || request.rest_path[4] == "latest"
          request.rest_path[4] = latest_version(list_data(request, request.rest_path[0..3]))
        end
        super(request)
      end

      def put(request)
        name = request.rest_path[3]
        version = request.rest_path[4]
        existing_cookbook = get_data(request, request.rest_path, :nil)

        # Honor frozen
        if existing_cookbook
          existing_cookbook_json = FFI_Yajl::Parser.parse(existing_cookbook)
          if existing_cookbook_json["frozen?"]
            if request.query_params["force"] != "true"
              raise RestErrorResponse.new(409, "The cookbook #{name} at version #{version} is frozen. Use the 'force' option to override.")
            end
            # For some reason, you are forever unable to modify "frozen?" on a frozen cookbook.
            request_body = FFI_Yajl::Parser.parse(request.body)
            if !request_body["frozen?"]
              request_body["frozen?"] = true
              request.body = FFI_Yajl::Encoder.encode(request_body, :pretty => true)
            end
          end
        end

        # Set the cookbook
        set_data(request, request.rest_path, populate_defaults(request, request.body), :create_dir, :create)

        # If the cookbook was updated, check for deleted files and clean them up
        if existing_cookbook
          missing_checksums = get_checksums(existing_cookbook) - get_checksums(request.body)
          if missing_checksums.size > 0
            hoover_unused_checksums(missing_checksums, request)
          end
        end

        already_json_response(existing_cookbook ? 200 : 201, populate_defaults(request, request.body, normalize: false))
      end

      def delete(request)
        if request.rest_path[4] == "_latest" || request.rest_path[4] == "latest"
          request.rest_path[4] = latest_version(list_data(request, request.rest_path[0..3]))
        end

        deleted_cookbook = get_data(request)

        response = super(request)
        # Last one out turns out the lights: delete /organizations/ORG/cookbooks/NAME if it no longer has versions
        cookbook_path = request.rest_path[0..3]
        if exists_data_dir?(request, cookbook_path) && list_data(request, cookbook_path).size == 0
          delete_data_dir(request, cookbook_path)
        end

        # Hoover deleted files, if they exist
        hoover_unused_checksums(get_checksums(deleted_cookbook), request)
        response
      end

      def get_checksums(cookbook)
        result = []
        FFI_Yajl::Parser.parse(cookbook).each_pair do |key, value|
          if value.is_a?(Array)
            value.each do |file|
              if file.is_a?(Hash) && file.has_key?("checksum")
                result << file["checksum"]
              end
            end
          end
        end
        result.uniq
      end

      private

      def hoover_unused_checksums(deleted_checksums, request)
        %w{cookbooks cookbook_artifacts}.each do |cookbook_type|
          begin
            cookbooks = data_store.list(request.rest_path[0..1] + [cookbook_type])
          rescue ChefZero::DataStore::DataNotFoundError
            # Not all chef versions support cookbook_artifacts
            raise unless cookbook_type == "cookbook_artifacts"
            cookbooks = []
          end
          cookbooks.each do |cookbook_name|
            # as below, this can be racy.
            begin
              data_store.list(request.rest_path[0..1] + [cookbook_type, cookbook_name]).each do |version|
                cookbook = data_store.get(request.rest_path[0..1] + [cookbook_type, cookbook_name, version], request)
                deleted_checksums = deleted_checksums - get_checksums(cookbook)
              end
            rescue ChefZero::DataStore::DataNotFoundError
            end
          end
        end
        deleted_checksums.each do |checksum|
          # There can be a race here if multiple cookbooks are uploading.
          # This deals with an exception on delete, but things can still get deleted
          # that shouldn't be.
          begin
            delete_data(request, request.rest_path[0..1] + ["file_store", "checksums", checksum], :data_store_exceptions)
          rescue ChefZero::DataStore::DataNotFoundError
          end
        end
      end

      def populate_defaults(request, response_json, normalize: true)
        # Inject URIs into each cookbook file
        cookbook = FFI_Yajl::Parser.parse(response_json)
        cookbook["chef_type"] ||= "cookbook_version"
        cookbook["json_class"] ||= "Chef::CookbookVersion"
        cookbook = ChefData::DataNormalizer.normalize_cookbook(self, request.rest_path[0..1], cookbook, request.rest_path[3], request.rest_path[4], request.base_uri, request.method, false, api_version: request.api_version) if normalize
        FFI_Yajl::Encoder.encode(cookbook, :pretty => true)
      end

      def latest_version(versions)
        sorted = versions.sort_by { |version| Gem::Version.new(version.dup) }
        sorted[-1]
      end
    end
  end
end
