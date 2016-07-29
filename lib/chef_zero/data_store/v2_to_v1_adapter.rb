#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2014 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef_zero/data_store/interface_v1"

module ChefZero
  module DataStore
    class V2ToV1Adapter < ChefZero::DataStore::InterfaceV1
      def initialize
        @single_org = "chef"
      end

      attr_reader :real_store
      attr_reader :single_org

      def clear
        real_store.clear
        real_store.create_dir([ "organizations" ], single_org, :recursive)
      end

      def create_dir(path, name, *options)
        fix_exceptions do
          real_store.create_dir(fix_path(path), name, *options)
        end
      end

      def create(path, name, data, *options)
        fix_exceptions do
          real_store.create(fix_path(path), name, data, *options)
        end
      end

      def get(path, request = nil)
        fix_exceptions do
          real_store.get(fix_path(path), request)
        end
      end

      def set(path, data, *options)
        fix_exceptions do
          real_store.set(fix_path(path), data, *options)
        end
      end

      def delete(path)
        fix_exceptions do
          real_store.delete(fix_path(path))
        end
      end

      def delete_dir(path, *options)
        fix_exceptions do
          real_store.delete_dir(fix_path(path), *options)
        end
      end

      def list(path)
        fix_exceptions do
          real_store.list(fix_path(path))
        end
      end

      def exists?(path)
        fix_exceptions do
          real_store.exists?(fix_path(path))
        end
      end

      def exists_dir?(path)
        fix_exceptions do
          real_store.exists_dir?(fix_path(path))
        end
      end

      protected

      def fix_exceptions
        begin
          yield
        rescue DataAlreadyExistsError => e
          raise DataAlreadyExistsError.new(e.path[2..-1], e)
        rescue DataNotFoundError => e
          raise DataNotFoundError.new(e.path[2..-1], e)
        end
      end

      def fix_path(path)
        [ "organizations", single_org ] + path
      end
    end
  end
end
