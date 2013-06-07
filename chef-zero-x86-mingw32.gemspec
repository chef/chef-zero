# x86-mingw32 Gemspec #
gemspec = eval(IO.read(File.expand_path("../chef-zero.gemspec", __FILE__)))

gemspec.platform = "x86-mingw32"

gemspec.add_dependency "puma", "~> 1.6" # puma 2.0 doesn't compile on Windows yet

gemspec
