require "chef_zero/rest_request"
require "chef_zero/rest_error_response"
require "chef_zero/data_store/data_not_found_error"
require "chef_zero/chef_data/acl_path"

module ChefZero
  class RestBase
    DEFAULT_REQUEST_VERSION = 0
    DEFAULT_RESPONSE_VERSION = 0

    def initialize(server)
      @server = server
    end

    attr_reader :server

    def data_store
      server.data_store
    end

    def check_api_version(request)
      version = request.api_version

      if version > MAX_API_VERSION || version < MIN_API_VERSION
        response = {
          "error" => "invalid-x-ops-server-api-version",
          "message" => "Specified version #{version} not supported",
          "min_api_version" => MIN_API_VERSION,
          "max_api_version" => MAX_API_VERSION,
        }

        return json_response(406,
                             response,
                             request_version: version, response_version: -1
                            )
      end
    rescue ArgumentError
      return json_response(406,
                           { "username" => request.requestor },
                           request_version: -1, response_version: -1
                          )
    end

    def call(request)
      response = check_api_version(request)
      return response unless response.nil?

      method = request.method.downcase.to_sym
      if !self.respond_to?(method)
        accept_methods = [:get, :put, :post, :delete].select { |m| self.respond_to?(m) }
        accept_methods_str = accept_methods.map { |m| m.to_s.upcase }.join(", ")
        return [405, { "Content-Type" => "text/plain", "Allow" => accept_methods_str }, "Bad request method for '#{request.env['REQUEST_PATH']}': #{request.env['REQUEST_METHOD']}"]
      end
      if json_only && !accepts?(request, "application", "json")
        return [406, { "Content-Type" => "text/plain" }, "Must accept application/json"]
      end
      # Dispatch to get()/post()/put()/delete()
      begin
        self.send(method, request)
      rescue RestErrorResponse => e
        ChefZero::Log.debug("#{e.inspect}\n#{e.backtrace.join("\n")}")
        error(e.response_code, e.error)
      end
    end

    def json_only
      true
    end

    def accepts?(request, category, type)
      # If HTTP_ACCEPT is not sent at all, assume it accepts anything
      # This parses as per http://tools.ietf.org/html/rfc7231#section-5.3
      return true if !request.env["HTTP_ACCEPT"]
      accepts = request.env["HTTP_ACCEPT"].split(/,\s*/).map { |x| x.split(";", 2)[0].strip }
      return accepts.include?("#{category}/#{type}") || accepts.include?("#{category}/*") || accepts.include?("*/*")
    end

    def get_data(request, rest_path = nil, *options)
      rest_path ||= request.rest_path
      rest_path = rest_path.map { |v| URI.decode(v) }
      begin
        data_store.get(rest_path, request)
      rescue DataStore::DataNotFoundError
        if options.include?(:nil)
          nil
        elsif options.include?(:data_store_exceptions)
          raise
        else
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, rest_path)}")
        end
      end
    end

    def list_data(request, rest_path = nil, *options)
      rest_path ||= request.rest_path
      begin
        data_store.list(rest_path)
      rescue DataStore::DataNotFoundError
        if options.include?(:data_store_exceptions)
          raise
        else
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, rest_path)}")
        end
      end
    end

    def delete_data(request, rest_path = nil, *options)
      rest_path ||= request.rest_path
      begin
        data_store.delete(rest_path, *options)
      rescue DataStore::DataNotFoundError
        if options.include?(:data_store_exceptions)
          raise
        else
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, rest_path)}")
        end
      end

      begin
        acl_path = ChefData::AclPath.get_acl_data_path(rest_path)
        data_store.delete(acl_path) if acl_path
      rescue DataStore::DataNotFoundError
      end
    end

    def delete_data_dir(request, rest_path, *options)
      rest_path ||= request.rest_path
      begin
        data_store.delete_dir(rest_path, *options)
      rescue DataStore::DataNotFoundError
        if options.include?(:data_store_exceptions)
          raise
        else
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, rest_path)}")
        end
      end

      begin
        acl_path = ChefData::AclPath.get_acl_data_path(rest_path)
        data_store.delete(acl_path) if acl_path
      rescue DataStore::DataNotFoundError
      end
    end

    def set_data(request, rest_path, data, *options)
      rest_path ||= request.rest_path
      begin
        data_store.set(rest_path, data, *options, :requestor => request.requestor)
      rescue DataStore::DataNotFoundError
        if options.include?(:data_store_exceptions)
          raise
        else
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, rest_path)}")
        end
      end
    end

    def create_data_dir(request, rest_path, name, *options)
      rest_path ||= request.rest_path
      begin
        data_store.create_dir(rest_path, name, *options, :requestor => request.requestor)
      rescue DataStore::DataNotFoundError
        if options.include?(:data_store_exceptions)
          raise
        else
          raise RestErrorResponse.new(404, "Parent not found: #{build_uri(request.base_uri, rest_path)}")
        end
      rescue DataStore::DataAlreadyExistsError
        if options.include?(:data_store_exceptions)
          raise
        else
          raise RestErrorResponse.new(409, "Object already exists: #{build_uri(request.base_uri, rest_path + [name])}")
        end
      end
    end

    def create_data(request, rest_path, name, data, *options)
      rest_path ||= request.rest_path
      begin
        data_store.create(rest_path, name, data, *options, :requestor => request.requestor)
      rescue DataStore::DataNotFoundError
        if options.include?(:data_store_exceptions)
          raise
        else
          raise RestErrorResponse.new(404, "Parent not found: #{build_uri(request.base_uri, rest_path)}")
        end
      rescue DataStore::DataAlreadyExistsError
        if options.include?(:data_store_exceptions)
          raise
        else
          raise RestErrorResponse.new(409, "Object already exists: #{build_uri(request.base_uri, rest_path + [name])}")
        end
      end
    end

    def exists_data?(request, rest_path = nil)
      rest_path ||= request.rest_path
      data_store.exists?(rest_path)
    end

    def exists_data_dir?(request, rest_path = nil)
      rest_path ||= request.rest_path
      data_store.exists_dir?(rest_path)
    end

    def error(response_code, error, opts = {})
      json_response(response_code, { "error" => [ error ] }, opts)
    end

    # Serializes `data` to JSON and returns an Array with the
    # response code, HTTP headers and JSON body.
    #
    # @param [Fixnum] response_code HTTP response code
    # @param [Hash] data The data for the response body as a Hash
    # @param [Hash] options
    # @option options [Hash] :headers (see #already_json_response)
    # @option options [Boolean] :pretty (true) Pretty-format the JSON
    # @option options [Fixnum] :request_version (see #already_json_response)
    # @option options [Fixnum] :response_version (see #already_json_response)
    #
    # @return (see #already_json_response)
    #
    def json_response(response_code, data, options = {})
      options = { pretty: true }.merge(options)
      do_pretty_json = !!options.delete(:pretty) # make sure we have a proper Boolean.
      json = FFI_Yajl::Encoder.encode(data, pretty: do_pretty_json)
      already_json_response(response_code, json, options)
    end

    def text_response(response_code, text)
      [response_code, { "Content-Type" => "text/plain" }, text]
    end

    # Returns an Array with the response code, HTTP headers, and JSON body.
    #
    # @param [Fixnum] response_code The HTTP response code
    # @param [String] json_text The JSON body for the response
    # @param [Hash] options
    # @option options [Hash] :headers ({}) HTTP headers (may override default headers)
    # @option options [Fixnum] :request_version (0) Request API version
    # @option options [Fixnum] :response_version (0) Response API version
    #
    # @return [Array(Fixnum, Hash{String => String}, String)]
    #
    def already_json_response(response_code, json_text, options = {})
      version_header = FFI_Yajl::Encoder.encode(
        "min_version" => MIN_API_VERSION.to_s,
        "max_version" => MAX_API_VERSION.to_s,
        "request_version" => options[:request_version] || DEFAULT_REQUEST_VERSION.to_s,
        "response_version" => options[:response_version] || DEFAULT_RESPONSE_VERSION.to_s
      )

      headers = {
        "Content-Type" => "application/json",
        "X-Ops-Server-API-Version" => version_header,
      }
      headers.merge!(options[:headers]) if options[:headers]

      [ response_code, headers, json_text ]
    end

    # To be called from inside rest endpoints
    def build_uri(base_uri, rest_path)
      if server.options[:single_org]
        # Strip off /organizations/chef if we are in single org mode
        if rest_path[0..1] != [ "organizations", server.options[:single_org] ]
          raise "Unexpected URL #{rest_path[0..1]} passed to build_uri in single org mode"
        end

        return self.class.build_uri(base_uri, rest_path[2..-1])
      end

      self.class.build_uri(base_uri, rest_path)
    end

    def self.build_uri(base_uri, rest_path)
      "#{base_uri}/#{rest_path.map { |v| URI.escape(v) }.join('/')}"
    end

    def populate_defaults(request, response)
      response
    end

    def parse_json(json)
      FFI_Yajl::Parser.parse(json)
    end

    def to_json(data)
      FFI_Yajl::Encoder.encode(data, :pretty => true)
    end

    def get_data_or_else(request, path, or_else_value)
      if exists_data?(request, path)
        parse_json(get_data(request, path))
      else
        or_else_value
      end
    end

    def list_data_or_else(request, path, or_else_value)
      if exists_data_dir?(request, path)
        list_data(request, path)
      else
        or_else_value
      end
    end

    def hashify_list(list)
      list.reduce({}) { |acc, obj| acc.merge( obj => {} ) }
    end

    def policy_name_invalid?(name)
      !name.is_a?(String) ||
        name.size > 255 ||
        name =~ /[+ !]/
    end
  end
end
