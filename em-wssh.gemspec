# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'em/wssh'

Gem::Specification.new do |spec|
  spec.name          = "em-wssh"
  spec.version       = EventMachine::Wssh::VERSION
  spec.authors       = ["Stas Ukolov"]
  spec.email         = ["ukoloff@gmail.com"]
  spec.description   = 'Proxy SSH connection through Websocket (nginx)'
  spec.summary       = ''
  spec.homepage      = "https://github.com/ukoloff/em-wssh"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "em-websocket"    # server side
  spec.add_dependency "faye-websocket"  # client side
  spec.add_dependency "openssl-win-root" if Gem.win_platform?

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
