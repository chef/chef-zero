require 'chef_zero/server'

describe ChefZero::Server do
  context 'with a server bound to port 8889' do
    before :each do
      @server = ChefZero::Server.new(:port => 8889)
      @server.start_background
    end
    after :each do
      @server.stop
    end

    it 'a second server bound to port 8889 throws EADDRINUSE' do
      expect { ChefZero::Server.new(:port => 8889).start }.to raise_error Errno::EADDRINUSE
    end

    it 'a server bound to range 8889-9999 binds to a port > 8889' do
      server = ChefZero::Server.new(:port => 8889.upto(9999))
      server.start_background
      expect(server.port).to be > 8889
      expect(URI(server.url).port).to be > 8889
    end

    it 'a server bound to range 8889-8889 throws an exception' do
      expect { ChefZero::Server.new(:port => 8889.upto(8889)).start_background }.to raise_error Errno::EADDRINUSE
    end
  end
end
