#!/usr/bin/env ruby
# frozen_string_literal: true

$blog_port = Integer(ARGV[0])

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'scorpio'
require_relative 'blog'

trap('INT') { ::Rack::Handler::WEBrick.shutdown }

webrick_logger = Logger.new(Pathname.new('log/blog_webrick.log'))
Rack::Handler::WEBrick.run(Blog,
  # see webrick/httpserver.rb
  Port: $blog_port,
  Logger: webrick_logger,
  # see webrick/accesslog.rb
  AccessLog: [
    # first should be an IO but the Logger works
    [webrick_logger, WEBrick::AccessLog::COMMON_LOG_FORMAT],
    [webrick_logger, WEBrick::AccessLog::REFERER_LOG_FORMAT],
  ],
)
