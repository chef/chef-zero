require "chef_zero/socketless_server_map"

describe "Socketless Mode" do

  let(:server_map) { ChefZero::SocketlessServerMap.instance.tap { |i| i.reset! } }

  let(:server) { instance_double("ChefZero::Server") }

  let(:second_server) { instance_double("ChefZero::Server") }

  it "registers a socketful server" do
    server_map.register_port(8889, server)
    expect(server_map).to have_server_on_port(8889)
  end

  it "retrieves a server by port" do
    server_map.register_port(8889, server)
    expect(ChefZero::SocketlessServerMap.server_on_port(8889)).to eq(server)
  end

  context "when a no-listen server is registered" do

    let!(:port) { server_map.register_no_listen_server(server) }

    it "assigns the server a low port number" do
      expect(port).to eq(1)
    end

    context "and another server is registered" do

      let!(:next_port) { server_map.register_no_listen_server(second_server) }

      it "assigns another port when another server is registered" do
        expect(next_port).to eq(2)
      end

      it "raises NoSocketlessPortAvailable when too many servers are registered" do
        expect { 1000.times { server_map.register_no_listen_server(server) } }.to raise_error(ChefZero::NoSocketlessPortAvailable)
      end

      it "deregisters a server" do
        expect(server_map).to have_server_on_port(1)
        server_map.deregister(1)
        expect(server_map).to_not have_server_on_port(1)
      end

      describe "routing requests to a server" do

        let(:rack_req) do
          r = {}
          r["REQUEST_METHOD"] = "GET"
          r["SCRIPT_NAME"] = ""
          r["PATH_INFO"] = "/clients"
          r["QUERY_STRING"] = ""
          r["rack.input"] = StringIO.new("")
          r
        end

        let(:rack_response) { [200, {}, ["this is the response body"] ] }

        it "routes a request to the registered port" do
          expect(server).to receive(:handle_socketless_request).with(rack_req).and_return(rack_response)
          response = server_map.request(1, rack_req)
          expect(response).to eq(rack_response)
        end

        it "raises ServerNotFound when a request is sent to an unregistered port" do
          expect { server_map.request(99, rack_req) }.to raise_error(ChefZero::ServerNotFound)
        end
      end
    end
  end

end
