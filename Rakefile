require "bundler/gem_tasks"

def run_oc_pedant(env = {})
  ENV.update(env)
  require File.expand_path("spec/run_oc_pedant")
end

ENV_DOCS = <<~END.freeze
  Environment:
   - RSPEC_OPTS   Options to pass to RSpec
                  e.g. RSPEC_OPTS="--fail-fast --profile 5"
   - PEDANT_OPTS  Options to pass to oc-chef-pedant
                  e.g. PEDANT_OPTS="--focus-keys --skip-users"
   - LOG_LEVEL    Set the log level (default: warn)
                  e.g. LOG_LEVEL=debug
END

task default: :pedant

desc "Run specs"
task :spec do
  system("rspec spec/*_spec.rb")
end

desc "Run oc-chef-pedant\n\n#{ENV_DOCS}"
task pedant: :oc_pedant

desc "Run oc-chef-pedant with CHEF_FS set\n\n#{ENV_DOCS}"
task :cheffs do
  run_oc_pedant("CHEF_FS" => "yes")
end

desc "Run oc-chef-pedant with FILE_STORE set\n\n#{ENV_DOCS}"
task :filestore do
  run_oc_pedant("FILE_STORE" => "yes")
end

task :oc_pedant do
  run_oc_pedant
end

task :chef_spec do
  gem_path = Bundler.environment.specs["chef"].first.full_gem_path
  system("cd #{gem_path} && rspec spec/integration")
end

desc "Check Linting and code style."
task :style do
  require "rubocop/rake_task"
  require "cookstyle/chefstyle"

  if RbConfig::CONFIG["host_os"] =~ /mswin|mingw|cygwin/
    # Windows-specific command, rubocop erroneously reports the CRLF in each file which is removed when your PR is uploaeded to GitHub.
    # This is a workaround to ignore the CRLF from the files before running cookstyle.
    sh "cookstyle --chefstyle -c .rubocop.yml --except Layout/EndOfLine"
  else
    sh "cookstyle --chefstyle -c .rubocop.yml"
  end
rescue LoadError
  puts "Rubocop or Cookstyle gems are not installed. bundle install first to make sure all dependencies are installed."
end

task :berkshelf_spec do
  gem_path = Bundler.environment.specs["berkshelf"].first.full_gem_path
  system("cd #{gem_path} && thor spec:ci")
end

begin
  require "yard" unless defined?(YARD)
  YARD::Rake::YardocTask.new(:docs)
rescue LoadError
  puts "yard is not available. bundle install first to make sure all dependencies are installed."
end
