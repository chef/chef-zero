require 'hashie'

class Hash
  include Hashie::Extensions::DeepMerge
end
