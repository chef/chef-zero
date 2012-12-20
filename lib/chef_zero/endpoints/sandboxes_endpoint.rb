require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /sandboxes
    class SandboxesEndpoint < RestBase
      def initialize(server)
        super(server)
        @next_id = 1
      end

      def post(request)
        sandbox_checksums = []

        needed_checksums = JSON.parse(request.body, :create_additions => false)['checksums']
        result_checksums = {}
        needed_checksums.keys.each do |needed_checksum|
          if data['file_store'].has_key?(needed_checksum)
            result_checksums[needed_checksum] = { :needs_upload => false }
          else
            result_checksums[needed_checksum] = {
              :needs_upload => true,
              :url => build_uri(request.base_uri, ['file_store', needed_checksum])
            }
            sandbox_checksums << needed_checksum
          end
        end

        id = @next_id.to_s
        @next_id+=1

        data['sandboxes'][id] = { :create_time => Time.now.utc, :checksums => sandbox_checksums }

        json_response(201, {
          :uri => build_uri(request.base_uri, request.rest_path + [id.to_s]),
          :checksums => result_checksums,
          :sandbox_id => id
        })
      end
    end
  end
end

