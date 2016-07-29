require "chef_zero/server"
require "net/http"
require "uri"

describe ChefZero::Server do
  context "with a server bound to port 8889" do
    before :each do
      @server = ChefZero::Server.new(:port => 8889)
      @server.start_background
    end
    after :each do
      @server.stop
    end

    it "a second server bound to port 8889 throws EADDRINUSE" do
      expect { ChefZero::Server.new(:port => 8889).start }.to raise_error Errno::EADDRINUSE
    end

    it "a server bound to range 8889-9999 binds to a port > 8889" do
      server = ChefZero::Server.new(:port => 8889.upto(9999))
      server.start_background
      expect(server.port).to be > 8889
      expect(URI(server.url).port).to be > 8889
    end

    it "a server bound to range 8889-8889 throws an exception" do
      expect { ChefZero::Server.new(:port => 8889.upto(8889)).start_background }.to raise_error Errno::EADDRINUSE
    end

    it "has a very patient request timeout" do
      expect(@server.server.config[:RequestTimeout]).to eq 300
    end

    context "accept headers" do
      def get_nodes(accepts)
        uri = URI(@server.url)
        httpcall = Net::HTTP.new(uri.host, uri.port)
        httpcall.get("/nodes", "Accept" => accepts)
      end

      def get_version
        uri = URI(@server.url)
        httpcall = Net::HTTP.new(uri.host, uri.port)
        httpcall.get("/version", "Accept" => "text/plain, application/json")
      end

      it "accepts requests with no accept header" do
        request = Net::HTTP::Get.new("/nodes")
        request.delete("Accept")
        uri = URI(@server.url)
        response = Net::HTTP.new(uri.host, uri.port).request(request)
        expect(response.code).to eq "200"
      end

      it "accepts requests with accept: application/json" do
        expect(get_nodes("application/json").code).to eq "200"
      end

      it "accepts requests with accept: application/*" do
        expect(get_nodes("application/*").code).to eq "200"
      end

      it "accepts requests with accept: application/*" do
        expect(get_nodes("*/*").code).to eq "200"
      end

      it "denies requests with accept: application/blah" do
        expect(get_nodes("application/blah").code).to eq "406"
      end

      it "denies requests with accept: blah/json" do
        expect(get_nodes("blah/json").code).to eq "406"
      end

      it "denies requests with accept: blah/*" do
        expect(get_nodes("blah/*").code).to eq "406"
      end

      it "denies requests with accept: blah/*" do
        expect(get_nodes("blah/*").code).to eq "406"
      end

      it "denies requests with accept: <empty string>" do
        expect(get_nodes("").code).to eq "406"
      end

      it "accepts requests with accept: a/b;a=b;c=d, application/json;a=b, application/xml;a=b" do
        expect(get_nodes("a/b;a=b;c=d, application/json;a=b, application/xml;a=b").code).to eq "200"
      end

      it "accepts /version" do
        expect(get_version.body.start_with?("chef-zero")).to be true
      end
    end
  end
end
