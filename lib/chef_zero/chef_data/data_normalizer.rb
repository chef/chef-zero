require 'chef_zero'
require 'chef_zero/rest_base'
require 'chef_zero/chef_data/default_creator'

module ChefZero
  module ChefData
    class DataNormalizer
      def self.normalize_acls(acls)
        ChefData::DefaultCreator::PERMISSIONS.each do |perm|
          acls[perm] ||= {}
          acls[perm]['actors'] ||= []
          acls[perm]['groups'] ||= []
        end
        acls
      end

      def self.normalize_client(client, name)
        client['name'] ||= name
        client['admin'] ||= false
        client['admin'] = !!client['admin']
        client['public_key'] ||= PUBLIC_KEY
        client['validator'] ||= false
        client['validator'] = !!client['validator']
        client['json_class'] ||= "Chef::ApiClient"
        client['chef_type'] ||= "client"
        client
      end

      def self.normalize_container(container, name)
        container.delete('id')
        container['containername'] = name
        container['containerpath'] = name
        container
      end

      def self.normalize_user(user, name, identity_keys, osc_compat, method=nil)
        user[identity_keys.first] ||= name
        user['public_key'] ||= PUBLIC_KEY
        user['admin'] ||= false
        user['admin'] = !!user['admin']
        user['openid'] ||= nil
        if !osc_compat
          if method == 'GET'
            user.delete('admin')
            user.delete('password')
            user.delete('openid')
          end
          user['email'] ||= nil
          user['first_name'] ||= nil
          user['last_name'] ||= nil
        end
        user
      end

      def self.normalize_data_bag_item(data_bag_item, data_bag_name, id, method)
        if method == 'DELETE'
          # TODO SERIOUSLY, WHO DOES THIS MANY EXCEPTIONS IN THEIR INTERFACE
          if !(data_bag_item['json_class'] == 'Chef::DataBagItem' && data_bag_item['raw_data'])
            data_bag_item['id'] ||= id
            data_bag_item = { 'raw_data' => data_bag_item }
            data_bag_item['chef_type'] ||= 'data_bag_item'
            data_bag_item['json_class'] ||= 'Chef::DataBagItem'
            data_bag_item['data_bag'] ||= data_bag_name
            data_bag_item['name'] ||= "data_bag_item_#{data_bag_name}_#{id}"
          end
        else
          # If it's not already wrapped with raw_data, wrap it.
          if data_bag_item['json_class'] == 'Chef::DataBagItem' && data_bag_item['raw_data']
            data_bag_item = data_bag_item['raw_data']
          end
          # Argh.  We don't do this on GET, but we do on PUT and POST????
          if %w(PUT POST).include?(method)
            data_bag_item['chef_type'] ||= 'data_bag_item'
            data_bag_item['data_bag'] ||= data_bag_name
          end
          data_bag_item['id'] ||= id
        end
        data_bag_item
      end

      def self.normalize_cookbook(endpoint, org_prefix, cookbook, name, version, base_uri, method)
        # TODO I feel dirty
        if method != 'PUT'
          cookbook.each_pair do |key, value|
            if value.is_a?(Array)
              value.each do |file|
                if file.is_a?(Hash) && file.has_key?('checksum')
                  file['url'] ||= endpoint.build_uri(base_uri, org_prefix + ['file_store', 'checksums', file['checksum']])
                end
              end
            end
          end
          cookbook['name'] ||= "#{name}-#{version}"
          # TODO this feels wrong, but the real chef server doesn't expand this default
    #      cookbook['version'] ||= version
          cookbook['cookbook_name'] ||= name
          cookbook['frozen?'] ||= false
          cookbook['metadata'] ||= {}
          cookbook['metadata']['version'] ||= version
          # Sad to not be expanding defaults just because Chef doesn't :(
  #        cookbook['metadata']['name'] ||= name
  #        cookbook['metadata']['description'] ||= "A fabulous new cookbook"
          cookbook['metadata']['long_description'] ||= ""
  #        cookbook['metadata']['maintainer'] ||= "YOUR_COMPANY_NAME"
  #        cookbook['metadata']['maintainer_email'] ||= "YOUR_EMAIL"
  #        cookbook['metadata']['license'] ||= "none"
          cookbook['metadata']['dependencies'] ||= {}
          cookbook['metadata']['attributes'] ||= {}
          cookbook['metadata']['recipes'] ||= {}
        end
        cookbook['json_class'] ||= 'Chef::CookbookVersion'
        cookbook['chef_type'] ||= 'cookbook_version'
        if method == 'MIN'
          cookbook['metadata'].delete('attributes')
          cookbook['metadata'].delete('long_description')
        end
        cookbook
      end

      def self.normalize_environment(environment, name)
        environment['name'] ||= name
        environment['description'] ||= ''
        environment['cookbook_versions'] ||= {}
        environment['json_class'] ||= "Chef::Environment"
        environment['chef_type'] ||= "environment"
        environment['default_attributes'] ||= {}
        environment['override_attributes'] ||= {}
        environment
      end

      def self.normalize_group(group, name, orgname)
        group.delete('id')
        if group['actors'].is_a?(Hash)
          group['users'] ||= group['actors']['users']
          group['clients'] ||= group['actors']['clients']
          group['groups'] ||= group['actors']['groups']
          group['actors'] = nil
        end
        group['users'] ||= []
        group['clients'] ||= []
        group['actors'] ||= (group['clients'] + group['users'])
        group['groups'] ||= []
        group['orgname'] ||= orgname if orgname
        group['name'] ||= name
        group['groupname'] ||= name

        group['users'].uniq!
        group['clients'].uniq!
        group['actors'].uniq!
        group['groups'].uniq!
        group
      end

      def self.normalize_node(node, name)
        node['name'] ||= name
        node['json_class'] ||= 'Chef::Node'
        node['chef_type'] ||= 'node'
        node['chef_environment'] ||= '_default'
        node['override'] ||= {}
        node['normal'] ||= {}
        node['default'] ||= {}
        node['automatic'] ||= {}
        node['run_list'] ||= []
        node['run_list'] = normalize_run_list(node['run_list'])
        node
      end

      def self.normalize_organization(org, name)
        org['name'] ||= name
        org['full_name'] ||= name
        org['org_type'] ||= 'Business'
        org['clientname'] ||= "#{name}-validator"
        org['billing_plan'] ||= 'platform-free'
        org
      end

      def self.normalize_role(role, name)
        role['name'] ||= name
        role['description'] ||= ''
        role['json_class'] ||= 'Chef::Role'
        role['chef_type'] ||= 'role'
        role['default_attributes'] ||= {}
        role['override_attributes'] ||= {}
        role['run_list'] ||= []
        role['run_list'] = normalize_run_list(role['run_list'])
        role['env_run_lists'] ||= {}
        role['env_run_lists'].each_pair do |env, run_list|
          role['env_run_lists'][env] = normalize_run_list(run_list)
        end
        role
      end

      def self.normalize_run_list(run_list)
        run_list.map{|item|
          case item
          when /^recipe\[.*\]$/
            item # explicit recipe
          when /^role\[.*\]$/
            item # explicit role
          else
            "recipe[#{item}]"
          end
        }.uniq
      end
    end
  end
end
