require 'chef_zero/rest_request'
require 'chef_zero/rest_error_response'
require 'chef/log'

module ChefZero
  class RestBase
    def initialize(server)
      @server = server
    end

    attr_reader :server

    def data
      server.data
    end

    def call(request)
      method = request.method.downcase.to_sym
      if !self.respond_to?(method)
        accept_methods = [:get, :put, :post, :delete].select { |m| self.respond_to?(m) }
        accept_methods_str = accept_methods.map { |m| m.to_s.upcase }.join(', ')
        return [405, {"Content-Type" => "text/plain", "Allow" => accept_methods_str}, "Bad request method for '#{env['REQUEST_PATH']}': #{env['REQUEST_METHOD']}"]
      end
      if json_only && !request.env['HTTP_ACCEPT'].split(';').include?('application/json')
        return [406, {"Content-Type" => "text/plain"}, "Must accept application/json"]
      end
      # Dispatch to get()/post()/put()/delete()
      begin
        self.send(method, request)
      rescue RestErrorResponse => e
        error(e.response_code, e.error)
      end
    end

    def json_only
      true
    end

    def get_data(request, rest_path=nil)
      rest_path ||= request.rest_path
      # Grab the value we're looking for
      value = data
      rest_path.each do |path_part|
        if !value.has_key?(path_part)
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, rest_path)}")
        end
        value = value[path_part]
      end
      value
    end

    def error(response_code, error)
      json_response(response_code, {"error" => [error]})
    end

    def json_response(response_code, json)
      already_json_response(response_code, JSON.pretty_generate(json))
    end

    def already_json_response(response_code, json_text)
      [response_code, {"Content-Type" => "application/json"}, json_text]
    end

    def build_uri(base_uri, rest_path)
      RestBase::build_uri(base_uri, rest_path)
    end

    def self.build_uri(base_uri, rest_path)
      "#{base_uri}/#{rest_path.join('/')}"
    end

    def populate_defaults(request, response)
      response
    end
  end
end
