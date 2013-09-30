require 'chef_zero/solr/solr_parser'
require 'chef_zero/solr/solr_doc'

describe ChefZero::Solr::SolrParser do
  let (:all_docs) do
    docs = []
    [{'foo' => 'a'},
     {'foo' => 'd'}].each_with_index do |h, i|
      docs.push ChefZero::Solr::SolrDoc.new(h, i)
    end
    docs
  end

  def search_for(query)
    q = ChefZero::Solr::SolrParser.new(query).parse
    all_docs.select {|doc| q.matches_doc?(doc) }
  end

  it "handles terms" do
    search_for('foo:d').size.should eq(1)
  end

  it "handles ranges" do
    search_for('foo:[a TO c]').size.should eq(1)
  end

  it "handles wildcard ranges" do
    search_for('foo:[* TO c]').size.should eq(1)
    search_for('foo:[c TO *]').size.should eq(1)
    search_for('foo:[* TO *]').size.should eq(2)
  end
end
