[![Stories in Ready](https://badge.waffle.io/opscode/chef-zero.png?label=ready&title=Ready)](https://waffle.io/opscode/chef-zero)[![Stories in Progress](https://badge.waffle.io/opscode/chef-zero.png?label=in+progress&title=In+Progress)](https://waffle.io/opscode/chef-zero)

Chef Zero
=========

Description
-----------
Chef Zero is a simple, easy-install, in-memory Chef server that can be useful
for Chef Client testing and chef-solo-like tasks that require a full Chef
Server. It IS intended to be simple, Chef 11 compliant, easy to run and fast
to start. It is NOT intended to be secure, scalable, performant or persistent.
It does NO input validation, authentication or authorization (it will not
throw a 400, 401 or 403). It does not save data, and will start up empty each
time you start it.

Because Chef Zero runs in memory, it's super fast and lightweight. This makes
it perfect for testing against a "real" Chef Server without mocking the
entire Internet.


Installation
------------
This server can be installed as a Ruby Gem.

    $ gem install chef-zero

If you're using bundler, add `chef-zero` as a development dependency:

```ruby
group :development do
  gem 'chef-zero'
end
```

Or in a `.gemspec`

```ruby
s.add_development_dependency 'chef-zero'
```

You can also clone the source repository and install it using `rake install`.

Usage
-----
One of chef-zero's primary uses is as a small test server for people writing and
testing clients. Here's a simple example of starting it up:

```ruby
require 'chef_zero/server'
server = ChefZero::Server.new(port: 4000)
server.start
```

This will create a server instance in the foreground. To stop the server:

```ruby
server.stop
```

This is great for debugging and logging requests, but you'll probably want
to run this in the background so you have full control of your thread.

To run Chef Zero in the background, simply issue the `start_background` command:

```ruby
require 'chef_zero/server'
server = ChefZero::Server.new(port: 4000)
server.start_background
```

You can stop the server the same way:

```ruby
server.stop
```

### Valid Options
You may currently pass the following options to the initializer:

- `host` - the host to run on (Default: '127.0.0.1')
- `port` - the port to run on (Default: 8889)
- `debug` - run in debug mode to see all requests and responses (Default: false)


CLI (Command Line)
-----------------
If you don't want to use Chef Zero as a library, you can simply start an instance
with the included `chef-zero` executable:

    $ chef-zero

Note, this will run in the foreground.

You now have a fully functional (empty) Chef Server running.

To try it out, go into the `chef-zero/playground` directory and run `knife`. It
will behave the same as a normal Chef Server, and all normal knife commands will
work (show, list, delete, from file, upload, download, diff ...). For example,
with +knife-essentials+ (or Chef 11) you can upload everything in the repo:

    chef-zero/playground> knife upload .
    Created nodes/desktop.json
    Created data_bags/dns
    Created environments/production.json
    Created nodes/lb.json
    Created nodes/dns.json
    Created nodes/ldap.json
    Created nodes/www.json
    Created data_bags/dns/services.json
    Created environments/staging.json
    Created data_bags/passwords
    Created data_bags/users
    Created data_bags/users/jkeiser.json
    Created data_bags/passwords/github.json
    Created data_bags/passwords/twitter.json
    Created data_bags/users/schisamo.json
    Created data_bags/users/sethvargo.json
    Created cookbooks/apache2
    Created cookbooks/php

    chef-zero/playground> knife environment list
    _default
    production
    staging

To use it in your own repository, create a `knife.rb` like so:

    chef_server_url   'http://127.0.0.1:8889'
    node_name         'stickywicket'
    client_key        'path_to_any_pem_file.pem'

And use knife like you normally would.

Since Chef Zero does no authentication, any `.pem` file will do. The client just
needs something to sign requests with (which will be ignored on the server). Even
though it's ignored, the `.pem` must still be a valid format.

Now, stop the Chef Zero server and all the data is gone!

Run `chef-zero --help` to see a list of the supported flags and options:

```text
Usage: chef-zero [ARGS]
    -H, --host HOST                  Host to bind to (default: 127.0.0.1)
    -p, --port PORT                  Port to listen on
        --[no-]generate-keys         Whether to generate actual keys or fake it (faster).  Default: false.
    -l, --log-level LEVEL            Set the output log level
    -h, --help                       Show this message
        --version                    Show version
```
