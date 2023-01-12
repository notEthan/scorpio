#!/usr/bin/env ruby
# frozen_string_literal: true

$blog_port = Integer(ARGV[0])

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'scorpio'
require_relative 'blog'

STDOUT.reopen(Scorpio.root.join('log/blog_webrick_stdout.log').open('a'))
STDERR.reopen(Scorpio.root.join('log/blog_webrick_stderr.log').open('a'))

trap('INT') { ::Rack::Handler::WEBrick.shutdown }

::Rack::Handler::WEBrick.run(::Blog, Port: $blog_port)
