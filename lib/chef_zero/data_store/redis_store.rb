#
# Copyright:: Copyright (c) 2015 Opscode, Inc.
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

require 'chef_zero/data_store/data_already_exists_error'
require 'chef_zero/data_store/data_not_found_error'
require 'chef_zero/data_store/interface_v2'
require 'chef/json_compat'
require 'redis'

module ChefZero
  module DataStore
    class RedisStore < ChefZero::DataStore::InterfaceV2
      # Usage:
      # require 'chef_zero'; require 'chef_zero/server'; require 'chef_zero/data_store/redis_store'
      # ChefZero::Server.new(data_store: ChefZero::DataStore::DefaultFacade.new(ChefZero::DataStore::RedisStore.new, "chef", true)).start

      def initialize(flushdb = false, redis_opts = {})
        @redis = Redis.new(redis_opts)
        clear if flushdb
      end

      attr_reader :data

      def clear
        @redis.flushdb
      end

      def create_dir(path, name, *options)
        return true
      end

      def create(path, name, data, *options)
        verbose_entry("===In: create #{path.to_s} ++ #{name}")
        if %w[users clients nodes roles environments data].include?(path.last)
          raise DataAlreadyExistsError.new(path + [name]) if @redis.hexists(path.join("/"), name)
        end
        @redis.hset(path.join("/"), name, data)
      end

      def get(path, request=nil)
        verbose_entry("===In: get #{path.to_s}")
        hkey, field = _split_path(path)
        data = @redis.hget(hkey.join("/"), field)
        raise DataNotFoundError.new(path) unless data
        data
      end

      def set(path, data, *options)
        verbose_entry("===In: set #{path.to_s}")
        hkey, field = _split_path(path)
        @redis.hset(hkey.join("/"), field, data)
      end

      def delete(path, *options)
        verbose_entry("===In: delete #{path.to_s}")
        hkey, field = _split_path(path)
        raise DataStore::DataNotFoundError.new(path) unless @redis.hexists(hkey.join("/"), field)
        @redis.hdel(hkey.join("/"), field)
      end

      def delete_dir(path, *options)
        true
      end

      def list(path)
        verbose_entry("===In: list #{path.to_s}")
        if %w[cookbooks].include?(path.last) && path.length < 4
          data = @redis.keys(path.join("/") + "/*").map {|key| key.split("/").last }
          raise DataNotFoundError.new(path) if data.empty?
          data
        elsif path.include?("data") && path.length < 5
          data = @redis.keys(path.join("/") + "/*").map {|key| key.split("/").last }
          data
        else
          data = @redis.hkeys(path.join("/"))
          raise DataNotFoundError.new(path) if data.empty?
          data
        end
      end

      def exists?(path, options = {})
        hkey, field = _split_path(path)
        @redis.hexists(hkey.join("/"), field)
      end

      def exists_dir?(path)
        verbose_entry("===In: exists_dir #{path.to_s}")
        return true if path.length < 3
        return true if @redis.hlen(path.join("/")) > 0
        false
      end

      private
      def _split_path(path)
        [path[0..-2], path.last]
      end

      def _data_type_to_path(type)
        if %w[environment role node client user principal].include?(type)
          type + "s"
        else
          type
        end
      end

      def verbose_entry(str)
        ## For debug with pedant.
        puts str if ENV['VERBOSE']
      end
    end
  end
end
