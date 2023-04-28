source 'https://rubygems.org'

gemspec

group(:dev) do
  platform(:mri) do
    if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7')
      gem('debug', '> 1')
    else
      gem('byebug')
    end
  end
  platform(:jruby) { gem('ruby-debug') }
end

gem 'rake'
gem 'gig'

group(:test) do
  gem('minitest', '~> 5.0')
  gem('minitest-around')
  gem('minitest-reporters')
  gem('simplecov')
  gem('simplecov-lcov')
  gem('sinatra', '~> 1.0')
  gem('rack', '~> 1.0')
  gem('rack-accept')
  gem('rack-test')
  gem('webrick')
  gem('api_hammer')
  activerecord_version =
    RUBY_ENGINE == 'truffleruby' ? '>= 6' : # TODO rm why is truffleruby using 5.x without this?
    RUBY_ENGINE == 'jruby' ? '< 7.1' : # TODO rm. some incompatibility with activerecord-jdbc-adapter at 7.1
    nil
  gem('activerecord', *activerecord_version)
  platform(:mri, :truffleruby) do
    gem('sqlite3', '~> 1.4') # loosen this in accordance with active_record/connection_adapters/sqlite3_adapter.rb
  end
  platform(:jruby) do
    gem('activerecord-jdbcsqlite3-adapter')
  end
  gem('database_cleaner')
end

group(:doc) do
  gem('yard')
end
