module ChefZero
  module Chef
      module Cookbook
      # Handles loading configuration values from a Chef config file
      #
      # @author Justin Campbell <justin.campbell@riotgames.com>
      class Metadata < Hash
        # @param [String] path
        def initialize(cookbook)
          self.name(cookbook.name)
          self.recipes(cookbook.fully_qualified_recipe_names)
        end

        def from_json(filepath)
          self.merge!(JSON.parse(File.read(filepath)))
        end

        private

          def method_missing(key, value = nil)
            if value.nil?
              self[key.to_sym]
            else
              store key.to_sym, value
            end
          end
      end
    end
  end
end
