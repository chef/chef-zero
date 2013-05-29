require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/rest_error_response'
require 'chef_zero/data_normalizer'

module ChefZero
  module Endpoints
    # /cookbooks/NAME/VERSION
    class CookbookVersionEndpoint < RestObjectEndpoint
      def get(request)
        if request.rest_path[2] == "_latest" || request.rest_path[2] == "latest"
          request.rest_path[2] = latest_version(list_data(request, request.rest_path[0..1]))
        end
        super(request)
      end

      def put(request)
        name = request.rest_path[1]
        version = request.rest_path[2]
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
        set_data(request, ['cookbooks', name, version], request.body, :create_dir, :create)

        # If the cookbook was updated, check for deleted files and clean them up
        if existing_cookbook
          missing_checksums = get_checksums(existing_cookbook) - get_checksums(request.body)
          if missing_checksums.size > 0
            hoover_unused_checksums(missing_checksums)
          end
        end

        already_json_response(existing_cookbook ? 200 : 201, populate_defaults(request, request.body))
      end

      def delete(request)
        if request.rest_path[2] == "_latest" || request.rest_path[2] == "latest"
          request.rest_path[2] = latest_version(list_data(request, request.rest_path[0..1]))
        end

        deleted_cookbook = get_data(request)

        response = super(request)
        cookbook_name = request.rest_path[1]
        delete_data_dir(request, ['cookbooks', cookbook_name]) if list_data(request, ['cookbooks', cookbook_name]).size == 0

        # Hoover deleted files, if they exist
        hoover_unused_checksums(get_checksums(deleted_cookbook))
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

      def hoover_unused_checksums(deleted_checksums)
        data_store.list(['cookbooks']).each do |cookbook_name|
          data_store.list(['cookbooks', cookbook_name]).each do |version|
            cookbook = data_store.get(['cookbooks', cookbook_name, version])
            deleted_checksums = deleted_checksums - get_checksums(cookbook)
          end
        end
        deleted_checksums.each do |checksum|
          # There can be a race here if multiple cookbooks are uploading.
          data_store.delete(['file_store', 'checksums', checksum])
        end
      end

      def populate_defaults(request, response_json)
        # Inject URIs into each cookbook file
        cookbook = JSON.parse(response_json, :create_additions => false)
        cookbook = DataNormalizer.normalize_cookbook(cookbook, request.rest_path[1], request.rest_path[2], request.base_uri, request.method)
        JSON.pretty_generate(cookbook)
      end

      def latest_version(versions)
        sorted = versions.sort_by { |version| Gem::Version.new(version.dup) }
        sorted[-1]
      end
    end
  end
end
