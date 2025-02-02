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
  gem('ostruct') if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.5')
  gem('rack', '~> 1.0')
  gem('rack-accept')
  gem('rack-test')
  gem('webrick')
  gem('api_hammer')

  # sqlite3 version is in accordance with active_record/connection_adapters/sqlite3_adapter.rb
  [
    {activerecord: '~> 8.0', ruby: '3.2', sqlite: '>= 2.1'},
    {activerecord: '~> 7.2', ruby: '3.1', sqlite: '>= 1.4'},
    {activerecord: '~> 7.0', ruby: '2.7', sqlite: '>= 1.4'},
    {activerecord: '~> 6.0', ruby: '2.5', sqlite: '~> 1.4'},
  ].map(&:values).each do |activerecord, ruby, sqlite|
    if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(ruby)
      if RUBY_ENGINE == 'jruby'
        # override. update this per released version of activerecord-jdbc-adapter, current latest 71.x corresponding to Rails 7.1.x
        activerecord = '< 7.2'
      end
      gem('activerecord', activerecord)

      platform(:mri, :truffleruby) do
        gem('sqlite3', sqlite)
      end
      break
    end
  end
  platform(:jruby) do
    gem('activerecord-jdbcsqlite3-adapter')
  end
  gem('database_cleaner')
end

group(:doc) do
  gem('yard')
end
