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
end
