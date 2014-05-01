source(ENV['BUNDLER_OVERRIDE_SOURCE'] || 'https://rubygems.org')

gemspec

local_gemfile = File.join(File.dirname(__FILE__), 'Gemfile.local')
instance_eval(File.read(local_gemfile)) if File.exist?(local_gemfile)
