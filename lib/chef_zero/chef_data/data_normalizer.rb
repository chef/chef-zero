require "chef_zero"
require "chef_zero/rest_base"
require "chef_zero/chef_data/default_creator"

module ChefZero
  module ChefData
    class DataNormalizer

      COOKBOOK_SEGMENTS = %w{ resources providers recipes definitions libraries attributes files templates root_files }

      def self.normalize_acls(acls)
        ChefData::DefaultCreator::PERMISSIONS.each do |perm|
          acls[perm] ||= {}
          acls[perm]["groups"] ||= []
          if acls[perm].has_key? "users"
            # When clients and users are split, their combined list
            # is the final list of actors that a subsequent GET will
            # provide. Each list is guaranteed to be unique, but the
            # combined list is not.
            acls[perm]["actors"] = acls[perm]["clients"].uniq +
              acls[perm]["users"].uniq
          else
            # this gets doubled sometimes, for reasons.
            (acls[perm]["actors"] ||= []).uniq!
          end
        end
        acls
      end

      def self.normalize_client(client, name, orgname = nil)
        client["name"] ||= name
        client["clientname"] ||= name
        client["admin"] = !!client["admin"] if client.key?("admin")
        client["public_key"] = PUBLIC_KEY unless client.key?("public_key")
        client["orgname"] ||= orgname
        client["validator"] ||= false
        client["validator"] = !!client["validator"]
        client["json_class"] ||= "Chef::ApiClient"
        client["chef_type"] ||= "client"
        client
      end

      def self.normalize_container(container, name)
        container.delete("id")
        container["containername"] = name
        container["containerpath"] = name
        container
      end

      def self.normalize_user(user, name, identity_keys, osc_compat, method = nil)
        user[identity_keys.first] ||= name
        user["public_key"] = PUBLIC_KEY unless user.key?("public_key")
        user["admin"] ||= false
        user["admin"] = !!user["admin"]
        user["openid"] ||= nil
        if !osc_compat
          if method == "GET"
            user.delete("admin")
            user.delete("password")
            user.delete("openid")
          end
          user["email"] ||= nil
          user["first_name"] ||= nil
          user["last_name"] ||= nil
        end
        user
      end

      def self.normalize_data_bag_item(data_bag_item, data_bag_name, id, method)
        if method == "DELETE"
          # TODO SERIOUSLY, WHO DOES THIS MANY EXCEPTIONS IN THEIR INTERFACE
          if !(data_bag_item["json_class"] == "Chef::DataBagItem" && data_bag_item["raw_data"])
            data_bag_item["id"] ||= id
            data_bag_item = { "raw_data" => data_bag_item }
            data_bag_item["chef_type"] ||= "data_bag_item"
            data_bag_item["json_class"] ||= "Chef::DataBagItem"
            data_bag_item["data_bag"] ||= data_bag_name
            data_bag_item["name"] ||= "data_bag_item_#{data_bag_name}_#{id}"
          end
        else
          # If it's not already wrapped with raw_data, wrap it.
          if data_bag_item["json_class"] == "Chef::DataBagItem" && data_bag_item["raw_data"]
            data_bag_item = data_bag_item["raw_data"]
          end
          # Argh.  We don't do this on GET, but we do on PUT and POST????
          if %w{PUT POST}.include?(method)
            data_bag_item["chef_type"] ||= "data_bag_item"
            data_bag_item["data_bag"] ||= data_bag_name
          end
          data_bag_item["id"] ||= id
        end
        data_bag_item
      end

      def self.normalize_cookbook(endpoint, org_prefix, cookbook, name, version, base_uri, method,
                                  is_cookbook_artifact = false, api_version: 2)
        # TODO I feel dirty
        if method == "PUT" && api_version < 2
          cookbook["all_files"] = cookbook.delete(["root_files"]) { [] }
          COOKBOOK_SEGMENTS.each do |segment|
            next unless cookbook.has_key? segment
            cookbook[segment].each do |file|
              file["name"] = "#{segment}/#{file['name']}"
              cookbook["all_files"] << file
            end
            cookbook.delete(segment)
          end
        elsif method != "PUT"
          if cookbook.key? "all_files"
            cookbook["all_files"].each do |file|
              if file.is_a?(Hash) && file.has_key?("checksum")
                file["url"] ||= endpoint.build_uri(base_uri, org_prefix + ["file_store", "checksums", file["checksum"]])
              end
            end

            # down convert to old style manifest, ensuring we don't send all_files on the wire and that we correctly divine segments
            # any file that's not in an old segment is just dropped on the floor.
            if api_version < 2

              # the spec appears to think we should send empty arrays for each segment, so let's do that
              COOKBOOK_SEGMENTS.each { |seg| cookbook[seg] ||= [] }

              cookbook["all_files"].each do |file|
                segment, name = file["name"].split("/")

                # root_files have no segment prepended
                if name.nil?
                  name = segment
                  segment = "root_files"
                end

                file.delete("full_path")
                next unless COOKBOOK_SEGMENTS.include? segment
                file["name"] = name
                cookbook[segment] << file
              end
              cookbook.delete("all_files")
            end
          end

          cookbook["name"] ||= "#{name}-#{version}"
          # TODO it feels wrong, but the real chef server doesn't expand 'version', so we don't either.

          cookbook["frozen?"] ||= false
          cookbook["metadata"] ||= {}
          cookbook["metadata"]["version"] ||= version

          # defaults set by the client and not the Server:
          # metadata[name, description, maintainer, maintainer_email, license]

          cookbook["metadata"]["long_description"] ||= ""
          cookbook["metadata"]["dependencies"] ||= {}
          cookbook["metadata"]["attributes"] ||= {}
          cookbook["metadata"]["recipes"] ||= {}
        end

        if is_cookbook_artifact
          cookbook.delete("json_class")
        else
          cookbook["cookbook_name"] ||= name
          cookbook["json_class"] ||= "Chef::CookbookVersion"
        end

        cookbook["chef_type"] ||= "cookbook_version"
        if method == "MIN"
          cookbook["metadata"].delete("attributes")
          cookbook["metadata"].delete("long_description")
        end
        cookbook
      end

      def self.normalize_environment(environment, name)
        environment["name"] ||= name
        environment["description"] ||= ""
        environment["cookbook_versions"] ||= {}
        environment["json_class"] ||= "Chef::Environment"
        environment["chef_type"] ||= "environment"
        environment["default_attributes"] ||= {}
        environment["override_attributes"] ||= {}
        environment
      end

      def self.normalize_group(group, name, orgname)
        group.delete("id")
        if group["actors"].is_a?(Hash)
          group["users"] ||= group["actors"]["users"]
          group["clients"] ||= group["actors"]["clients"]
          group["groups"] ||= group["actors"]["groups"]
          group["actors"] = nil
        end
        group["users"] ||= []
        group["clients"] ||= []
        group["actors"] ||= (group["clients"] + group["users"])
        group["groups"] ||= []
        group["orgname"] ||= orgname if orgname
        group["name"] ||= name
        group["groupname"] ||= name

        group["users"].uniq!
        group["clients"].uniq!
        group["actors"].uniq!
        group["groups"].uniq!
        group
      end

      def self.normalize_node(node, name)
        node["name"] ||= name
        node["json_class"] ||= "Chef::Node"
        node["chef_type"] ||= "node"
        node["chef_environment"] ||= "_default"
        node["override"] ||= {}
        node["normal"] ||= { "tags" => [] }
        node["default"] ||= {}
        node["automatic"] ||= {}
        node["run_list"] ||= []
        node["run_list"] = normalize_run_list(node["run_list"])
        node
      end

      def self.normalize_policy(policy, name, revision)
        policy["name"] ||= name
        policy["revision_id"] ||= revision
        policy["run_list"] ||= []
        policy["cookbook_locks"] ||= {}
        policy
      end

      def self.normalize_policy_group(policy_group, name)
        policy_group[name] ||= "name"
        policy_group["policies"] ||= {}
        policy_group
      end

      def self.normalize_organization(org, name)
        org["name"] ||= name
        org["full_name"] ||= name
        org["org_type"] ||= "Business"
        org["clientname"] ||= "#{name}-validator"
        org["billing_plan"] ||= "platform-free"
        org
      end

      def self.normalize_role(role, name)
        role["name"] ||= name
        role["description"] ||= ""
        role["json_class"] ||= "Chef::Role"
        role["chef_type"] ||= "role"
        role["default_attributes"] ||= {}
        role["override_attributes"] ||= {}
        role["run_list"] ||= []
        role["run_list"] = normalize_run_list(role["run_list"])
        role["env_run_lists"] ||= {}
        role["env_run_lists"].each_pair do |env, run_list|
          role["env_run_lists"][env] = normalize_run_list(run_list)
        end
        role
      end

      def self.normalize_run_list(run_list)
        run_list.map do |item|
          case item
          when /^recipe\[.*\]$/
            item # explicit recipe
          when /^role\[.*\]$/
            item # explicit role
          else
            "recipe[#{item}]"
          end
        end.uniq
      end
    end
  end
end
