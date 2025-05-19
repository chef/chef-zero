require "chef_zero/solr/solr_parser"
require "chef_zero/solr/solr_doc"

describe ChefZero::Solr::SolrParser do
  let(:all_docs) do
    docs = []
    [{ "foo" => "a" },
     { "foo" => "d" }].each_with_index do |h, i|
       docs.push ChefZero::Solr::SolrDoc.new(h, i)
     end
    docs
  end

  def search_for(query)
    q = ChefZero::Solr::SolrParser.new(query).parse
    all_docs.select { |doc| q.matches_doc?(doc) }
  end

  it "handles terms" do
    expect(search_for("foo:d").size).to eq(1)
  end

  it "handles ranges" do
    expect(search_for("foo:[a TO c]").size).to eq(1)
  end

  it "handles -" do
    expect(search_for("-foo:a").size).to eq(1)
  end

  it "handles wildcard ranges" do
    expect(search_for("foo:[* TO c]").size).to eq(1)
    expect(search_for("foo:[c TO *]").size).to eq(1)
    expect(search_for("foo:[* TO *]").size).to eq(2)
  end
end
