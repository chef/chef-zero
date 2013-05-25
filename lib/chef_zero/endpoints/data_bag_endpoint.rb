require 'json'
require 'chef_zero/endpoints/rest_list_endpoint'
require 'chef_zero/endpoints/data_bag_item_endpoint'
require 'chef_zero/rest_error_response'

module ChefZero
  module Endpoints
    # /data/NAME
    class DataBagEndpoint < RestListEndpoint
      def initialize(server)
        super(server, 'id')
      end

      def post(request)
        key = JSON.parse(request.body, :create_additions => false)[identity_key]
        response = super(request)
        if response[0] == 201
          already_json_response(201, DataBagItemEndpoint::populate_defaults(request, request.body, request.rest_path[1], key))
        else
          response
        end
      end

      def get_key(contents)
        data_bag_item = JSON.parse(contents, :create_additions => false)
        if data_bag_item['json_class'] == 'Chef::DataBagItem' && data_bag_item['raw_data']
          data_bag_item['raw_data']['id']
        else
          data_bag_item['id']
        end
      end

      def delete(request)
        key = request.rest_path[1]
        delete_data_dir(request, request.rest_path, :recursive)
        json_response(200, {
          'chef_type' => 'data_bag',
          'json_class' => 'Chef::DataBag',
          'name' => key
        })
      end
    end
  end
end

