$:.unshift File.expand_path("../lib", __FILE__)

require "vagrant-windows-sysprep/version"

Gem::Specification.new do |gem|
  gem.name          = "vagrant-windows-sysprep"
  gem.version       = VagrantPlugins::WindowsSysprep::VERSION
  gem.platform      = Gem::Platform::RUBY
  gem.license       = "LGPLv3"
  gem.authors       = "Rui Lopes"
  gem.email         = "rgl@ruilopes.com"
  gem.homepage      = "https://github.com/rgl/vagrant-windows-sysprep"
  gem.description   = "Vagrant plugin for running Windows sysprep."
  gem.summary       = "Vagrant plugin for running Windows sysprep."
  gem.files         = Dir.glob("lib/**/*").reject {|p| File.directory? p}
  gem.require_path  = "lib"

  gem.add_development_dependency "rake"
end
