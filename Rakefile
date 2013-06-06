require 'bundler'
require 'bundler/gem_helper'

# Get build, install and release tasks for each gem flavor
%w(chef-zero chef-zero-x86-mingw32).each do |gem_name|
  Bundler::GemHelper.install_tasks :name => gem_name
end

task :spec do
  sh 'ruby spec/run.rb'
end
