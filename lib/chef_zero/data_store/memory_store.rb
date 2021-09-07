#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require_relative "v2_to_v1_adapter"
require_relative "memory_store_v2"
require_relative "default_facade"

module ChefZero
  module DataStore
    class MemoryStore < ChefZero::DataStore::V2ToV1Adapter
      def initialize
        super
        @real_store = ChefZero::DataStore::DefaultFacade.new(ChefZero::DataStore::MemoryStoreV2.new, "chef", true)
        clear
      end
    end
  end
end
