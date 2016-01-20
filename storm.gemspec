# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'storm/version'

Gem::Specification.new do |spec|
  spec.name          = "storm"
  spec.version       = Storm::VERSION
  spec.authors       = ["Timothy Sherratt"]
  spec.email         = ["tim@mitoo.co"]
  spec.summary       = %q{STeak ORM}
  spec.description   = %q{Data Mapper pattern ORM for Steak}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "sqlite3"

  spec.add_runtime_dependency "activemodel"
  spec.add_runtime_dependency "activerecord"
  spec.add_runtime_dependency "activesupport"
end
