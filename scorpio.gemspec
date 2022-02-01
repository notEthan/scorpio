# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scorpio/version'

Gem::Specification.new do |spec|
  spec.name          = "scorpio"
  spec.version       = Scorpio::VERSION
  spec.authors       = ["Ethan"]
  spec.email         = ["ethan@unth.net"]

  spec.summary       = 'Scorpio REST client'
  spec.description   = 'ORM style REST client'
  spec.homepage      = "https://github.com/notEthan/scorpio"
  spec.license       = "AGPL-3.0"
  ignore_files = %w(.gitignore .github Gemfile test)
  ignore_files_re = %r{\A(#{ignore_files.map { |f| Regexp.escape(f) }.join('|')})(/|\z)}
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(ignore_files_re) }
  spec.test_files    = `git ls-files -z test`.split("\x0")
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "jsi", "~> 0.6.0"
  spec.add_dependency "ur", "~> 0.2.1"
  spec.add_dependency "faraday", "~> 1.0"
end
