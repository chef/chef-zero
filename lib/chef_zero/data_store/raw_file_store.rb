#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
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

require "chef_zero/data_store/data_already_exists_error"
require "chef_zero/data_store/data_not_found_error"
require "chef_zero/data_store/interface_v2"
require "fileutils"

module ChefZero
  module DataStore
    class RawFileStore < ChefZero::DataStore::InterfaceV2
      def initialize(root, destructible = false)
        @root = root
        @destructible = destructible
      end

      attr_reader :root
      attr_reader :destructible

      def path_to(path, name = nil)
        if name
          File.join(root, *path, name)
        else
          File.join(root, *path)
        end
      end

      def clear
        if destructible
          Dir.entries(root).each do |entry|
            next if entry == "." || entry == ".."
            FileUtils.rm_rf(Path.join(root, entry))
          end
        end
      end

      def create_dir(path, name, *options)
        real_path = path_to(path, name)
        if options.include?(:recursive)
          FileUtils.mkdir_p(real_path)
        else
          begin
            Dir.mkdir(File.join(path, name))
          rescue Errno::ENOENT
            raise DataNotFoundError.new(path)
          rescue Errno::EEXIST
            raise DataAlreadyExistsError.new(path + [name])
          end
        end
      end

      def create(path, name, data, *options)
        if options.include?(:create_dir)
          FileUtils.mkdir_p(path_to(path))
        end
        begin
          File.open(path_to(path, name), File::WRONLY | File::CREAT | File::EXCL | File::BINARY, :internal_encoding => nil) do |file|
            file.write data
          end
        rescue Errno::ENOENT
          raise DataNotFoundError.new(path)
        rescue Errno::EEXIST
          raise DataAlreadyExistsError.new(path + [name])
        end
      end

      def get(path, request = nil)
        begin
          return IO.read(path_to(path))
        rescue Errno::ENOENT
          raise DataNotFoundError.new(path)
        end
      end

      def set(path, data, *options)
        if options.include?(:create_dir)
          FileUtils.mkdir_p(path_to(path[0..-2]))
        end
        begin
          mode = File::WRONLY | File::TRUNC | File::BINARY
          if options.include?(:create)
            mode |= File::CREAT
          end
          File.open(path_to(path), mode, :internal_encoding => nil) do |file|
            file.write data
          end
        rescue Errno::ENOENT
          raise DataNotFoundError.new(path)
        end
      end

      def delete(path)
        begin
          File.delete(path_to(path))
        rescue Errno::ENOENT
          raise DataNotFoundError.new(path)
        end
      end

      def delete_dir(path, *options)
        if options.include?(:recursive)
          if !File.exist?(path_to(path))
            raise DataNotFoundError.new(path)
          end
          FileUtils.rm_rf(path_to(path))
        else
          begin
            Dir.rmdir(path_to(path))
          rescue Errno::ENOENT
            raise DataNotFoundError.new(path)
          end
        end
      end

      def list(path)
        begin
          Dir.entries(path_to(path)).select { |entry| entry != "." && entry != ".." }.to_a
        rescue Errno::ENOENT
          raise DataNotFoundError.new(path)
        end
      end

      def exists?(path, options = {})
        File.exists?(path_to(path))
      end

      def exists_dir?(path)
        File.exists?(path_to(path))
      end
    end
  end
end
