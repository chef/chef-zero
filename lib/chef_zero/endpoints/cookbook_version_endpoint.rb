require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/rest_error_response'
require 'chef_zero/data_normalizer'
require 'chef_zero/data_store/data_not_found_error'

module ChefZero
  module Endpoints
    # /cookbooks/NAME/VERSION
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
          existing_cookbook_json = JSON.parse(existing_cookbook, :create_additions => false)
          if existing_cookbook_json['frozen?']
            if request.query_params['force'] != "true"
              raise RestErrorResponse.new(409, "The cookbook #{name} at version #{version} is frozen. Use the 'force' option to override.")
            end
            # For some reason, you are forever unable to modify "frozen?" on a frozen cookbook.
            request_body = JSON.parse(request.body, :create_additions => false)
            if !request_body['frozen?']
              request_body['frozen?'] = true
              request.body = JSON.pretty_generate(request_body)
            end
          end
        end

        # Set the cookbook
        set_data(request, request.rest_path[0..1] + ['cookbooks', name, version], request.body, :create_dir, :create)

        # If the cookbook was updated, check for deleted files and clean them up
        if existing_cookbook
          missing_checksums = get_checksums(existing_cookbook) - get_checksums(request.body)
          if missing_checksums.size > 0
            hoover_unused_checksums(missing_checksums, request)
          end
        end

        already_json_response(existing_cookbook ? 200 : 201, populate_defaults(request, request.body))
      end

      def delete(request)
        if request.rest_path[4] == "_latest" || request.rest_path[4] == "latest"
          request.rest_path[4] = latest_version(list_data(request, request.rest_path[0..3]))
        end

        deleted_cookbook = get_data(request)

        response = super(request)
        cookbook_name = request.rest_path[3]
        if exists_data_dir?(request, request.rest_path[0..1] + [ 'cookbooks', cookbook_name ]) && list_data(request, request.rest_path[0..1] + ['cookbooks', cookbook_name]).size == 0
          delete_data_dir(request, request.rest_path[0..1] + ['cookbooks', cookbook_name])
        end

        # Hoover deleted files, if they exist
        hoover_unused_checksums(get_checksums(deleted_cookbook), request)
        response
      end

      def get_checksums(cookbook)
        result = []
        JSON.parse(cookbook, :create_additions => false).each_pair do |key, value|
          if value.is_a?(Array)
            value.each do |file|
              if file.is_a?(Hash) && file.has_key?('checksum')
                result << file['checksum']
              end
            end
          end
        end
        result.uniq
      end

      private

      def hoover_unused_checksums(deleted_checksums, request)
        data_store.list(request.rest_path[0..1] + ['cookbooks']).each do |cookbook_name|
          data_store.list(request.rest_path[0..1] + ['cookbooks', cookbook_name]).each do |version|
            cookbook = data_store.get(request.rest_path[0..1] + ['cookbooks', cookbook_name, version], request)
            deleted_checksums = deleted_checksums - get_checksums(cookbook)
          end
        end
        deleted_checksums.each do |checksum|
          # There can be a race here if multiple cookbooks are uploading.
          # This deals with an exception on delete, but things can still get deleted
          # that shouldn't be.
          begin
            data_store.delete(request.rest_path[0..1] + ['file_store', 'checksums', checksum])
          rescue ChefZero::DataStore::DataNotFoundError
          end
        end
      end

      def populate_defaults(request, response_json)
        # Inject URIs into each cookbook file
        cookbook = JSON.parse(response_json, :create_additions => false)
        cookbook = DataNormalizer.normalize_cookbook(self, request.rest_path[0..1], cookbook, request.rest_path[3], request.rest_path[4], request.base_uri, request.method)
        JSON.pretty_generate(cookbook)
      end

      def latest_version(versions)
        sorted = versions.sort_by { |version| Gem::Version.new(version.dup) }
        sorted[-1]
      end
    end
  end
end
