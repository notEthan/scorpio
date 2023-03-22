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
gem 'rack', '~> 3.0'
gem 'rack-accept'
gem 'rack-test'
gem 'webrick'
gem 'api_hammer'
gem 'activerecord'
platform(:mri) do
  gem 'sqlite3', '~> 1.4' # loosen this in accordance with active_record/connection_adapters/sqlite3_adapter.rb
end
platform(:jruby) do
  gem 'activerecord-jdbcsqlite3-adapter'
end
gem 'database_cleaner'
gem 'yard'
