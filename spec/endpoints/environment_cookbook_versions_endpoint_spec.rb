require "uri" unless defined?(URI)
require "chef_zero/endpoints/environment_cookbook_versions_endpoint"

describe ChefZero::Endpoints::EnvironmentCookbookVersionsEndpoint do
  let(:server) { double("server") }
  let(:endpoint) { described_class.new(server) }

  describe "#sort_versions" do
    it "returns versions sorted descending by semver" do
      versions = ["1.0.0", "2.0.0", "1.5.0", "0.9.0"]
      expect(endpoint.sort_versions(versions)).to eq(["2.0.0", "1.5.0", "1.0.0", "0.9.0"])
    end

    it "handles single-element lists" do
      expect(endpoint.sort_versions(["1.0.0"])).to eq(["1.0.0"])
    end

    it "handles an empty list" do
      expect(endpoint.sort_versions([])).to eq([])
    end

    it "sorts multi-digit version components numerically" do
      versions = ["1.2.3", "1.10.0", "1.9.0"]
      expect(endpoint.sort_versions(versions)).to eq(["1.10.0", "1.9.0", "1.2.3"])
    end
  end

  describe "#filter_by_constraint" do
    let(:versions) { { "apache" => ["1.0.0", "1.5.0", "2.0.0", "2.1.0"] } }

    it "returns versions unchanged when constraint is nil" do
      result = endpoint.filter_by_constraint(versions, "apache", nil)
      expect(result["apache"]).to eq(["1.0.0", "1.5.0", "2.0.0", "2.1.0"])
    end

    it "filters with an exact version constraint" do
      result = endpoint.filter_by_constraint(versions, "apache", "= 1.5.0")
      expect(result["apache"]).to eq(["1.5.0"])
    end

    it "filters with a >= constraint" do
      result = endpoint.filter_by_constraint(versions, "apache", ">= 2.0.0")
      expect(result["apache"]).to eq(["2.0.0", "2.1.0"])
    end

    it "filters with a ~> constraint" do
      result = endpoint.filter_by_constraint(versions, "apache", "~> 1.0")
      expect(result["apache"]).to eq(["1.0.0", "1.5.0"])
    end

    it "returns empty array when no versions match" do
      result = endpoint.filter_by_constraint(versions, "apache", "= 9.9.9")
      expect(result["apache"]).to eq([])
    end

    it "does not mutate the original versions hash" do
      original = versions.dup
      endpoint.filter_by_constraint(versions, "apache", "= 1.0.0")
      expect(versions).to eq(original)
    end
  end

  describe "#depsolve" do
    let(:org_prefix) { %w{organizations testorg} }
    let(:request) { double("request", rest_path: org_prefix + %w{environments _default cookbook_versions}) }
    let(:data_store) { double("data_store") }

    before do
      allow(server).to receive(:data_store).and_return(data_store)
    end

    def cookbook_json(name, version, dependencies = {})
      FFI_Yajl::Encoder.encode({
        "metadata" => {
          "name" => name,
          "version" => version,
          "dependencies" => dependencies,
        },
      })
    end

    context "base cases" do
      it "returns [nil, nil] when a cookbook has empty versions" do
        desired = { "apache" => [] }
        result, _cache = endpoint.depsolve(request, ["apache"], desired, {})
        expect(result).to be_nil
      end

      it "sets @last_constraint_failure when a cookbook has empty versions" do
        desired = { "apache" => [] }
        endpoint.depsolve(request, ["apache"], desired, {})
        expect(endpoint.instance_variable_get(:@last_constraint_failure)).to eq("apache")
      end

      it "returns desired_versions when unsolved list is empty" do
        desired = { "apache" => ["1.0.0"] }
        result, _cache = endpoint.depsolve(request, [], desired, {})
        expect(result).to eq(desired)
      end

      it "resolves a cookbook with no metadata key" do
        desired = { "minimal" => ["1.0.0"] }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "minimal", "1.0.0"], request)
          .and_return(FFI_Yajl::Encoder.encode({}))

        result, cache = endpoint.depsolve(request, ["minimal"], desired, {})
        expect(result["minimal"]).to eq(["1.0.0"])
        expect(cache["minimal"]).to have_key("1.0.0")
      end
    end

    context "simple resolution" do
      it "resolves a single cookbook with no dependencies" do
        desired = { "apache" => ["1.0.0", "2.0.0"] }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "2.0.0"], request)
          .and_return(cookbook_json("apache", "2.0.0"))
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0"))

        result, cache = endpoint.depsolve(request, ["apache"], desired, {})
        expect(result["apache"]).to eq(["2.0.0"])
        expect(cache["apache"]["2.0.0"]).to be_a(Hash)
      end

      it "resolves a cookbook with a satisfiable dependency" do
        desired = { "apache" => ["1.0.0"] }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0", { "mysql" => ">= 1.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(true)
        allow(data_store).to receive(:list)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(["1.0.0", "2.0.0"])
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "mysql", "2.0.0"], request)
          .and_return(cookbook_json("mysql", "2.0.0"))
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "mysql", "1.0.0"], request)
          .and_return(cookbook_json("mysql", "1.0.0"))

        result, _cache = endpoint.depsolve(request, ["apache"], desired, {})
        expect(result["apache"]).to eq(["1.0.0"])
        expect(result["mysql"]).to eq(["2.0.0"])
      end

      it "returns [nil, nil] when a dependency cookbook does not exist" do
        desired = { "apache" => ["1.0.0"] }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0", { "missing" => ">= 0.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks missing})
          .and_return(false)

        result, _cache = endpoint.depsolve(request, ["apache"], desired, {})
        expect(result).to be_nil
        expect(endpoint.instance_variable_get(:@last_missing_dep)).to eq("missing")
      end
    end

    context "constraint filtering" do
      it "applies environment constraints to dependency versions" do
        desired = { "apache" => ["1.0.0"] }
        env_constraints = { "mysql" => "= 1.0.0" }

        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0", { "mysql" => ">= 0.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(true)
        allow(data_store).to receive(:list)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(["1.0.0", "2.0.0"])
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "mysql", "1.0.0"], request)
          .and_return(cookbook_json("mysql", "1.0.0"))

        result, _cache = endpoint.depsolve(request, ["apache"], desired, env_constraints)
        expect(result["mysql"]).to eq(["1.0.0"])
      end

      it "filters dependency versions by the dependency's own constraint" do
        desired = { "apache" => ["1.0.0"] }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0", { "mysql" => ">= 2.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(true)
        allow(data_store).to receive(:list)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(["1.0.0", "2.0.0"])
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "mysql", "2.0.0"], request)
          .and_return(cookbook_json("mysql", "2.0.0"))

        result, _cache = endpoint.depsolve(request, ["apache"], desired, {})
        expect(result["mysql"]).to eq(["2.0.0"])
      end

      it "returns nil when dep constraint filters out all available versions" do
        desired = { "apache" => ["1.0.0"] }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0", { "mysql" => ">= 5.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(true)
        allow(data_store).to receive(:list)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(["1.0.0", "2.0.0"])

        result, _cache = endpoint.depsolve(request, ["apache"], desired, {})
        expect(result).to be_nil
      end
    end

    context "backtracking" do
      it "falls back to an older version when newest has unsatisfiable dep" do
        desired = { "web" => ["1.0.0", "2.0.0"] }
        # v2.0.0 depends on "ghost" which doesn't exist
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "web", "2.0.0"], request)
          .and_return(cookbook_json("web", "2.0.0", { "ghost" => ">= 0.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks ghost})
          .and_return(false)
        # v1.0.0 has no deps
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "web", "1.0.0"], request)
          .and_return(cookbook_json("web", "1.0.0"))

        result, _cache = endpoint.depsolve(request, ["web"], desired, {})
        expect(result["web"]).to eq(["1.0.0"])
      end

      it "backtracks through multiple failing versions" do
        desired = { "web" => ["1.0.0", "2.0.0", "3.0.0"] }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "web", "3.0.0"], request)
          .and_return(cookbook_json("web", "3.0.0", { "missing_a" => ">= 0.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks missing_a})
          .and_return(false)
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "web", "2.0.0"], request)
          .and_return(cookbook_json("web", "2.0.0", { "missing_b" => ">= 0.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks missing_b})
          .and_return(false)
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "web", "1.0.0"], request)
          .and_return(cookbook_json("web", "1.0.0"))

        result, _cache = endpoint.depsolve(request, ["web"], desired, {})
        expect(result["web"]).to eq(["1.0.0"])
      end
    end

    context "multiple cookbooks and dependencies" do
      it "populates cache entries for all resolved cookbooks" do
        desired = { "apache" => ["1.0.0"] }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0", { "mysql" => ">= 1.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(true)
        allow(data_store).to receive(:list)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(["1.0.0"])
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "mysql", "1.0.0"], request)
          .and_return(cookbook_json("mysql", "1.0.0"))

        _result, cache = endpoint.depsolve(request, ["apache"], desired, {})
        expect(cache["apache"]).to have_key("1.0.0")
        expect(cache["apache"]["1.0.0"]["metadata"]["name"]).to eq("apache")
        expect(cache["mysql"]).to have_key("1.0.0")
        expect(cache["mysql"]["1.0.0"]["metadata"]["name"]).to eq("mysql")
      end

      it "resolves multiple independent unsolved cookbooks" do
        desired = {
          "apache" => ["1.0.0", "2.0.0"],
          "nginx" => ["3.0.0", "4.0.0"],
        }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "2.0.0"], request)
          .and_return(cookbook_json("apache", "2.0.0"))
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0"))
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "nginx", "4.0.0"], request)
          .and_return(cookbook_json("nginx", "4.0.0"))
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "nginx", "3.0.0"], request)
          .and_return(cookbook_json("nginx", "3.0.0"))

        result, cache = endpoint.depsolve(request, %w{apache nginx}, desired, {})
        expect(result["apache"]).to eq(["2.0.0"])
        expect(result["nginx"]).to eq(["4.0.0"])
        expect(cache.keys).to contain_exactly("apache", "nginx")
      end

      it "resolves a diamond dependency (two cookbooks sharing a dep)" do
        desired = {
          "apache" => ["1.0.0"],
          "nginx" => ["1.0.0"],
        }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0", { "mysql" => ">= 1.0.0" }))
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "nginx", "1.0.0"], request)
          .and_return(cookbook_json("nginx", "1.0.0", { "mysql" => ">= 2.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(true)
        allow(data_store).to receive(:list)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(["1.0.0", "2.0.0", "3.0.0"])
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "mysql", "3.0.0"], request)
          .and_return(cookbook_json("mysql", "3.0.0"))
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "mysql", "2.0.0"], request)
          .and_return(cookbook_json("mysql", "2.0.0"))

        result, _cache = endpoint.depsolve(request, %w{apache nginx}, desired, {})
        expect(result["apache"]).to eq(["1.0.0"])
        expect(result["nginx"]).to eq(["1.0.0"])
        expect(result["mysql"]).to eq(["3.0.0"])
      end

      it "returns nil when dependency constraints from two cookbooks conflict" do
        desired = {
          "apache" => ["1.0.0"],
          "nginx" => ["1.0.0"],
        }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "apache", "1.0.0"], request)
          .and_return(cookbook_json("apache", "1.0.0", { "mysql" => ">= 2.0.0" }))
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "nginx", "1.0.0"], request)
          .and_return(cookbook_json("nginx", "1.0.0", { "mysql" => "< 2.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(true)
        allow(data_store).to receive(:list)
          .with(org_prefix + %w{cookbooks mysql})
          .and_return(["1.0.0", "2.0.0"])

        result, _cache = endpoint.depsolve(request, %w{apache nginx}, desired, {})
        expect(result).to be_nil
      end

      it "resolves a deep dependency chain" do
        desired = { "app" => ["1.0.0"] }
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "app", "1.0.0"], request)
          .and_return(cookbook_json("app", "1.0.0", { "framework" => ">= 1.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks framework})
          .and_return(true)
        allow(data_store).to receive(:list)
          .with(org_prefix + %w{cookbooks framework})
          .and_return(["1.0.0"])
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "framework", "1.0.0"], request)
          .and_return(cookbook_json("framework", "1.0.0", { "lib" => ">= 1.0.0" }))
        allow(data_store).to receive(:exists_dir?)
          .with(org_prefix + %w{cookbooks lib})
          .and_return(true)
        allow(data_store).to receive(:list)
          .with(org_prefix + %w{cookbooks lib})
          .and_return(["1.0.0", "2.0.0"])
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "lib", "2.0.0"], request)
          .and_return(cookbook_json("lib", "2.0.0"))
        allow(data_store).to receive(:get)
          .with(org_prefix + ["cookbooks", "lib", "1.0.0"], request)
          .and_return(cookbook_json("lib", "1.0.0"))

        result, cache = endpoint.depsolve(request, ["app"], desired, {})
        expect(result["app"]).to eq(["1.0.0"])
        expect(result["framework"]).to eq(["1.0.0"])
        expect(result["lib"]).to eq(["2.0.0"])
        expect(cache.keys).to contain_exactly("app", "framework", "lib")
      end
    end
  end
end
