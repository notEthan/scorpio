source 'https://rubygems.org'

gemspec

gem 'rake'
gem 'gig'
gem 'minitest', '~> 5.0'
gem 'minitest-around'
gem 'minitest-reporters'
gem 'simplecov'
gem 'simplecov-lcov'
gem 'sinatra', '~> 1.0'
gem 'rack', '~> 1.0'
gem 'rack-accept'
gem 'rack-test'
gem 'webrick'
gem 'api_hammer'
activerecord_version =
  RUBY_ENGINE == 'truffleruby' ? '>= 6' : # TODO rm why is truffleruby using 5.x without this?
  RUBY_ENGINE == 'jruby' ? '< 7.1' : # TODO rm. some incompatibility with activerecord-jdbc-adapter at 7.1
  nil
gem('activerecord', *activerecord_version)
platform(:mri) do
  gem 'sqlite3', '~> 1.4' # loosen this in accordance with active_record/connection_adapters/sqlite3_adapter.rb
end
platform(:jruby) do
  gem 'activerecord-jdbcsqlite3-adapter'
end
gem 'database_cleaner'
gem 'yard'
