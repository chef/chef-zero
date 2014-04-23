require 'chef_zero/data_store/interface_v1'

module ChefZero
  module DataStore
    # V2 assumes paths starting with /organizations/ORGNAME.  It also REQUIRES that
    # new organizations have these defaults:
    # chef-validator client: '{ "validator": true }',
    # chef-webui client: '{ "admin": true }'
    # _default environment: '{ "description": "The default Chef environment" }'
    # admin user: '{ "admin": "true" }'

    class InterfaceV2 < ChefZero::DataStore::InterfaceV1
      def interface_version
        2
      end
    end
  end
end
