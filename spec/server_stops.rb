require 'bundler'
require 'bundler/setup'
require 'rspec'

require 'chef_zero/server'

describe ChefZero::Server do
  describe '#stop' do
    context 'when the server is started in the background' do
      let(:server) do
        server = ChefZero::Server.new()
        server.start_background
        server
      end
      it 'stops' do
        server.stop
        expect(server.running?).to eq false
      end
    end
  end
end