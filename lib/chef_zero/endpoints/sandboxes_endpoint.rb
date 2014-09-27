require 'ffi_yajl'
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

        needed_checksums = FFI_Yajl::Parser.parse(request.body, :create_additions => false)['checksums']
        result_checksums = {}
        needed_checksums.keys.each do |needed_checksum|
          if list_data(request, request.rest_path[0..1] + ['file_store', 'checksums']).include?(needed_checksum)
            result_checksums[needed_checksum] = { :needs_upload => false }
          else
            result_checksums[needed_checksum] = {
              :needs_upload => true,
              :url => build_uri(request.base_uri, request.rest_path[0..1] + ['file_store', 'checksums', needed_checksum])
            }
            sandbox_checksums << needed_checksum
          end
        end

        # There is an obvious race condition here.
        id = @next_id.to_s
        @next_id+=1

        time_str = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S%z')
        time_str = "#{time_str[0..21]}:#{time_str[22..23]}"

        create_data(request, request.rest_path, id, FFI_Yajl::Encoder.encode({
          :create_time => time_str,
          :checksums => sandbox_checksums
        }, :pretty => true))

        json_response(201, {
          :uri => build_uri(request.base_uri, request.rest_path + [id]),
          :checksums => result_checksums,
          :sandbox_id => id
        })
      end
    end
  end
end
