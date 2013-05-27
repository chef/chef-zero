require 'chef_zero/rest_request'
require 'chef_zero/rest_error_response'
require 'chef_zero/data_store/data_not_found_error'

module ChefZero
  class RestBase
    def initialize(server)
      @server = server
    end

    attr_reader :server

    def data_store
      server.data_store
    end

    def call(request)
      method = request.method.downcase.to_sym
      if !self.respond_to?(method)
        accept_methods = [:get, :put, :post, :delete].select { |m| self.respond_to?(m) }
        accept_methods_str = accept_methods.map { |m| m.to_s.upcase }.join(', ')
        return [405, {"Content-Type" => "text/plain", "Allow" => accept_methods_str}, "Bad request method for '#{request.env['REQUEST_PATH']}': #{request.env['REQUEST_METHOD']}"]
      end
      if json_only && request.env['HTTP_ACCEPT'] && !request.env['HTTP_ACCEPT'].split(';').include?('application/json')
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

    def get_data(request, rest_path=nil, *options)
      rest_path ||= request.rest_path
      begin
        data_store.get(rest_path, request)
      rescue DataStore::DataNotFoundError
        if options.include?(:nil)
          nil
        else
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, rest_path)}")
        end
      end
    end

    def list_data(request, rest_path=nil)
      rest_path ||= request.rest_path
      begin
        data_store.list(rest_path)
      rescue DataStore::DataNotFoundError
        raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, rest_path)}")
      end
    end

    def delete_data(request, rest_path=nil)
      rest_path ||= request.rest_path
      begin
        data_store.delete(rest_path)
      rescue DataStore::DataNotFoundError
        raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
      end
    end

    def delete_data_dir(request, rest_path, *options)
      rest_path ||= request.rest_path
      begin
        data_store.delete_dir(rest_path)
      rescue DataStore::DataNotFoundError
        raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
      end
    end

    def set_data(request, rest_path, data, *options)
      rest_path ||= request.rest_path
      begin
        data_store.set(rest_path, request.body, *options)
      rescue DataStore::DataNotFoundError
        raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
      end
    end

    def create_data(request, rest_path, name, data, *options)
      rest_path ||= request.rest_path
      begin
        data_store.create(rest_path, name, data, *options)
      rescue DataStore::DataNotFoundError
        raise RestErrorResponse.new(404, "Parent not found: #{build_uri(request.base_uri, request.rest_path)}")
      rescue DataStore::DataAlreadyExistsError
        raise RestErrorResponse.new(409, "Object already exists: #{build_uri(request.base_uri, request.rest_path + [name])}")
      end
    end

    def exists_data?(request, rest_path=nil)
      rest_path ||= request.rest_path
      data_store.exists?(rest_path)
    end

    def exists_data_dir?(request, rest_path=nil)
      rest_path ||= request.rest_path
      data_store.exists_dir?(rest_path)
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
