# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'backup/version'

Gem::Specification.new do |spec|
  spec.name          = 'backup'
  spec.version       = Backup::VERSION
  spec.authors       = ['Stephen H. Gerstacker']
  spec.email         = ['stephen@airsquirrels.com']

  spec.summary       = 'Backup files to Amazon Glacier'
  spec.description   = 'Backup given directories and databases to ' \
    'Amazon Glacier'
  spec.homepage      = 'https://shortround.net'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set
  # the 'allowed_push_host' to allow pushing to a single host or delete
  # this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk', '~> 2.10'
  spec.add_dependency 'concurrent-ruby', '~> 1.0'
  spec.add_dependency 'eventmachine', '~> 1.2'

  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.49.1'
end
