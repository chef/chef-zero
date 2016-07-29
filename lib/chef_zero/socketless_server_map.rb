#
# Author:: Daniel DeLeo (<dan@chef.io>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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

require "thread"
require "singleton"

module ChefZero

  class ServerNotFound < StandardError
  end

  class NoSocketlessPortAvailable < StandardError
  end

  class SocketlessServerMap

    def self.request(port, request_env)
      instance.request(port, request_env)
    end

    def self.server_on_port(port)
      instance.server_on_port(port)
    end

    MUTEX = Mutex.new

    include Singleton

    def initialize()
      reset!
    end

    def reset!
      @servers_by_port = {}
    end

    def register_port(port, server)
      MUTEX.synchronize do
        @servers_by_port[port] = server
      end
    end

    def register_no_listen_server(server)
      MUTEX.synchronize do
        1.upto(1000) do |port|
          unless @servers_by_port.key?(port)
            @servers_by_port[port] = server
            return port
          end
        end
        raise NoSocketlessPortAvailable, "No socketless ports left to register"
      end
    end

    def has_server_on_port?(port)
      @servers_by_port.key?(port)
    end

    def server_on_port(port)
      @servers_by_port[port]
    end

    def deregister(port)
      MUTEX.synchronize do
        @servers_by_port.delete(port)
      end
    end

    def request(port, request_env)
      server = @servers_by_port[port]
      raise ServerNotFound, "No socketless chef-zero server on given port #{port.inspect}" unless server
      server.handle_socketless_request(request_env)
    end

  end
end
