package "apache2"

template "/etc/apache2/sites-enabled" do
  source "site.conf.erb"
end
