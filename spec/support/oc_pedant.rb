# Copyright: Copyright (c) 2012 Opscode, Inc.
# License: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This annotated Pedant configuration file details the various
# configuration settings available to you.  It is separate from the
# actual Pedant::Config class because not all settings have sane
# defaults, and not all settings are appropriate in all settings.

################################################################################
# You MUST specify the address of the server the API requests will be
# sent to.  Only specify protocol, hostname, and port.
chef_server "http://127.0.0.1:8889"

# If you are doing development testing, you can specify the address of
# the Solr server.  The presence of this parameter will enable tests
# to force commits to Solr, greatly decreasing the amout of time
# needed for testing the search endpoint.  This is only an
# optimization for development!  If you are testing a "live" Chef
# Server, or otherwise do not have access to the Solr server from your
# testing location, you should not specify a value for this parameter.
# The tests will still run, albeit slower, as they will now need to
# poll for a period to ensure they are querying committed results.
#search_server "http://localhost:8983"

# Related to the 'search_server' parameter, this specifies the maximum
# amout of time (in seconds) that search endpoint requests should be
# retried before giving up.  If not explicitly set, it will default to
# 65 seconds; only set it if you know that your Solr commit interval
# differs significantly from this.
maximum_search_time 0

# OSC sends erchef a host header with a port, so this option needs
# # to be enabled for Pedant tests to work correctly
explicit_port_url true

server_api_version 0

internal_server chef_server

# see dummy_endpoint.rb for details.
search_server   chef_server
search_commit_url "/dummy"
search_url_fmt    "/dummy?fq=+X_CHEF_type_CHEF_X:%{type}&q=%{query}&wt=json"

# We're starting to break tests up into groups based on different
# criteria.  The proper API tests (the results of which are viewable
# to OPC customers) should be the only ones run by Pedant embedded in
# OPC installs.  There are other specs that help us keep track of API
# cruft that we want to come back and fix later; these shouldn't be
# viewable to customers, but we should be able to run them in
# development and CI environments.  If this parameter is missing or
# explicitly `false` only the customer-friendly tests will be run.
#
# This is mainly here for documentation purposes, since the
# command-line `opscode-pedant` utility ultimately determines this
# value.
include_internal false

key = "spec/support/stickywicket.pem"

org(name: "pedant-testorg",
    create_me: !ENV["CHEF_FS"],
    validator_key: key)

internal_account_url chef_server
delete_org true

# Test users.  The five users specified below are required; their
# names (:user, :non_org_user, etc.) are indicative of their role
# within the tests.  All users must have a ':name' key.  If they have
# a ':create_me' key, Pedant will create these users for you.  If you
# are using pre-existing users, you must supply a ':key_file' key,
# which should be the fully-qualified path /on the machine Pedant is
# running on/ to a private key for that user.
superuser_name "pivotal"

def cheffs_or_else_user(value)
  ENV["CHEF_FS"] ? "pivotal" : value
end

keyfile_maybe = ENV["CHEF_FS"] ? { key_file: key } : { key_file: nil }

requestors({
             :clients => {
               # The the admin user, for the purposes of getting things rolling
               :admin => {
                 :name => "pedant_admin_client",
                 :create_me => true,
                 :create_knife => true,
                 :admin => true,
               },
               :non_admin => {
                 :name => "pedant_client",
                 :create_me => true,
                 :create_knife => true,
               },
               :bad => {
                 :name => "bad_client",
                 :create_me => true,
                 :create_knife => true,
                 :bogus => true,
               },
             },

             :users => {
               # An administrator in the testing organization
               :admin => {
                 :name => cheffs_or_else_user("pedant_admin_user"),
                 :create_me => !ENV["CHEF_FS"],
                 :associate => !ENV["CHEF_FS"],
                 :create_knife => true,
               }.merge(keyfile_maybe),

               :non_admin => {
                 :name => cheffs_or_else_user("pedant_user"),
                 :create_me => !ENV["CHEF_FS"],
                 :associate => !ENV["CHEF_FS"],
                 :create_knife => true,
               }.merge(keyfile_maybe),

               # A user that is not a member of the testing organization
               :bad => {
                 :name => cheffs_or_else_user("pedant-nobody"),
                 :create_me => !ENV["CHEF_FS"],
                 :create_knife => true,
                 :associate => false,
               }.merge(keyfile_maybe),
             },
           })

self[:tags] = [:validation, :authentication, :authorization]
verify_error_messages false

ruby_users_endpoint? false
ruby_acls_endpoint? false
ruby_org_assoc? false
chef_12? true
