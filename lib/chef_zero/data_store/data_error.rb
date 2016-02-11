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

module ChefZero
  module DataStore
    class DataError < StandardError
      attr_reader :path, :cause

      def initialize(path, cause = nil)
        @path = path
        @cause = cause
        path_for_msg = path.nil? ? "nil" : "/#{path.join('/')}"
        super "Data path: #{path_for_msg}"
      end
    end
  end
end
