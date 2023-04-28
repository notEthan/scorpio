# frozen_string_literal: true

if ENV['CI'] || ENV['COV']
  require 'simplecov'
  SimpleCov.start do
    if ENV['CI']
      require 'simplecov-lcov'

      SimpleCov::Formatter::LcovFormatter.config do |c|
        c.report_with_single_file = true
        c.single_report_path = 'coverage/lcov.info'
      end

      formatter SimpleCov::Formatter::LcovFormatter
    else
      coverage_dir '{coverage}'
    end
  end
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'scorpio'

require('bundler')
bundler_groups = [:default]
bundler_groups << :dev unless ENV['CI']
Bundler.setup(*bundler_groups)

if !ENV['CI'] && Bundler.load.specs.any? { |spec| spec.name == 'debug' }
  require('debug')
  Object.send(:alias_method, :dbg, :debugger)
end

# NO EXPECTATIONS 
ENV["MT_NO_EXPECTATIONS"] = ''

require 'minitest/autorun'
require 'minitest/around/spec'
require 'minitest/reporters'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class ScorpioSpec < Minitest::Spec
  if ENV['SCORPIO_TEST_ALPHA']
    # :nocov:
    define_singleton_method(:test_order) { :alpha }
    # :nocov:
  end

  around do |test|
    test.call
    BlogClean.clean
  end

  def assert_equal exp, act, msg = nil
    msg = message(msg, E) { diff exp, act }
    assert exp == act, msg
  end
end

# register this to be the base class for specs instead of Minitest::Spec
Minitest::Spec.register_spec_type(//, ScorpioSpec)

# boot the blog application in a different process

# find a free port
require 'socket'
server = TCPServer.new(0)
$blog_port = server.addr[1]
server.close

$blog_pid = spawn(RbConfig.ruby, File.join(__dir__, "blog_server.rb"), $blog_port.to_s)

# wait for the server to become responsive 
running = false
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
timeout = 99 # seconds
while !running
  begin
    sock = TCPSocket.new('localhost', $blog_port)
    running = true
    sock.close
    STDOUT.puts("web server running on port #{$blog_port}")
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE
    if Process.clock_gettime(Process::CLOCK_MONOTONIC) > started + timeout
      raise $!.class, "Failed to connect to the server on port #{$blog_port} after #{timeout} seconds.\n\n#{$!.message}", $!.backtrace
    end
    sleep 2**-2
    STDOUT.write('.')
  end
end

Minitest.after_run do
  Process.kill('INT', $blog_pid)
  Process.waitpid
end

require_relative 'blog_scorpio_models'
