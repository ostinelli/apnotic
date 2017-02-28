# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'apnotic/version'

Gem::Specification.new do |spec|
  spec.name                  = "apnotic"
  spec.version               = Apnotic::VERSION
  spec.licenses              = ['MIT']
  spec.authors               = ["Roberto Ostinelli"]
  spec.email                 = ["roberto@ostinelli.net"]
  spec.summary               = %q{Apnotic is an Apple Push Notification gem able to provide instant feedback.}
  spec.homepage              = "http://github.com/ostinelli/apnotic"
  spec.required_ruby_version = '>=2.1.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "net-http2", ">= 0.15", "< 2"
  spec.add_dependency "connection_pool", "~> 2.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
