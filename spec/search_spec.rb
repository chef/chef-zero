require 'chef_zero/solr/solr_parser'
require 'chef_zero/solr/solr_doc'

#p = ChefZero::Solr::SolrParser.new('chef_environment:prod AND roles:redis_history_server AND -redis_slaveof:[a TO z]')

describe ChefZero::Solr::SolrParser do
  let (:all_docs) do
    docs = []
    [{'foo' => 1},
     {'foo' => 7}].each_with_index do |h, i|
      docs.push ChefZero::Solr::SolrDoc.new(h, i)
    end
    docs
  end

  it "handles terms" do
    q = ChefZero::Solr::SolrParser.new('foo:7').parse
    results = all_docs.select {|doc| q.matches_doc?(doc) }
    results.size.should eq(1)
  end

  it "handles ranges" do
    q = ChefZero::Solr::SolrParser.new('foo:[1 TO 5]').parse
    results = all_docs.select {|doc| q.matches_doc?(doc) }
    results.size.should eq(1)
  end
end
