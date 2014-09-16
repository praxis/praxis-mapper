lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'praxis-mapper/version'

Gem::Specification.new do |spec|
  spec.name          = "praxis-mapper"
  spec.version       = Praxis::Mapper::VERSION
  spec.authors = ["Josep M. Blanquer","Dane Jensen"]
  spec.date = "2014-08-18"
  spec.summary       = %q{A multi-datastore library designed for efficiency in loading large datasets.}
  spec.email = ["blanquer@gmail.com","dane.jensen@gmail.com"]
  
  spec.homepage = "https://github.com/rightscale/praxis-mapper"
  spec.license = "MIT"
  spec.required_ruby_version = ">=2.1"

  spec.require_paths = ["lib"]
  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  
  spec.add_runtime_dependency(%q<randexp>, ["~> 0"])
  spec.add_runtime_dependency(%q<sequel>, ["~> 4"])
  spec.add_runtime_dependency(%q<activesupport>, [">= 3"])

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 0"

  spec.add_development_dependency(%q<redcarpet>, ["< 3.0"])
  spec.add_development_dependency(%q<yard>, ["~> 0.8.7"])
  spec.add_development_dependency(%q<guard>, ["~> 2"])
  spec.add_development_dependency(%q<guard-rspec>, [">= 0"])
  spec.add_development_dependency(%q<rspec>, ["< 2.99"])
  spec.add_development_dependency(%q<pry>, ["~> 0"])
  spec.add_development_dependency(%q<pry-byebug>, ["~> 1"])
  spec.add_development_dependency(%q<pry-stack_explorer>, ["~> 0"])
  spec.add_development_dependency(%q<fuubar>, ["~> 1"])
end
