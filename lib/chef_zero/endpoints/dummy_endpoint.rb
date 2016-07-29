
# pedant makes a couple of Solr-related calls from its search_utils.rb file that we can't work around (e.g.
# with monkeypatching). the necessary Pedant::Config values are set in run_oc_pedant.rb. --cdoherty
module ChefZero
  module Endpoints
    class DummyEndpoint < RestBase
      # called by #direct_solr_query, once each for roles, nodes, and data bag items. each RSpec example makes
      # 3 calls, with the expected sequence of return values [0, 1, 0].
      def get(request)
        # this could be made less brittle, but if things change to have more than 3 cycles, we should really
        # be notified by a spec failure.
        @mock_values ||= ([0, 1, 0] * 3).map { |val| make_response(val) }

        retval = @mock_values.shift
        json_response(200, retval)
      end

      # called by #force_solr_commit in pedant's , which doesn't check the return value.
      def post(request)
        # sure thing!
        json_response(200, { message: "This dummy POST endpoint didn't do anything." })
      end

      def make_response(value)
        { "response" => { "numFound" => value } }
      end
    end
  end
end
