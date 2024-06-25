require_relative('lib/scorpio/version')

Gem::Specification.new do |spec|
  spec.name          = "scorpio"
  spec.version       = Scorpio::VERSION
  spec.authors       = ["Ethan"]
  spec.email         = ["ethan@unth.net"]

  spec.summary       = 'Scorpio REST client'
  spec.description   = 'ORM style REST client'
  spec.homepage      = "https://github.com/notEthan/scorpio"
  spec.license       = "AGPL-3.0"

  spec.files = [
    'LICENSE.md',
    'CHANGELOG.md',
    'README.md',
    '.yardopts',
    'scorpio.gemspec',
    *Dir['lib/**/*'],
    *Dir['documents/**/*'],
  ].reject { |f| File.lstat(f).ftype == 'directory' }

  spec.require_paths = ["lib"]

  spec.add_dependency "jsi", "~> 0.8.1"
  spec.add_dependency "ur", "~> 0.2.5"
  spec.add_dependency "faraday", "< 3.0"
  spec.add_dependency "addressable", '~> 2.3'
end
