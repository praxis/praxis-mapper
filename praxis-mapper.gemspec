lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'praxis-mapper/version'


Gem::Specification.new do |spec|
  spec.name          = "praxis-mapper"
  spec.version       = Praxis::Mapper::VERSION
  spec.authors       = ["RightScale, Inc."]
  spec.summary       = %q{Praxis Mapper.}
  spec.description   = %q{Praxis Mapper. Should add more here.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency(%q<randexp>, [">= 0"])
  spec.add_runtime_dependency(%q<sequel>, [">= 0"])
  spec.add_runtime_dependency(%q<activesupport>, [">= 0"])

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

  spec.add_development_dependency(%q<redcarpet>, ["< 3.0"])
  spec.add_development_dependency(%q<yard>, [">= 0"])
  spec.add_development_dependency(%q<guard>, [">= 0"])
  spec.add_development_dependency(%q<guard-rspec>, [">= 0"])
  spec.add_development_dependency(%q<rspec>, ["< 2.99"])
  #s.add_development_dependency('simplecov', ['>= 0'])
  spec.add_development_dependency(%q<fuubar>, [">= 0"])
  spec.add_development_dependency(%q<pry>, [">= 0"])
  spec.add_development_dependency(%q<pry-byebug>, [">= 0"])
  spec.add_development_dependency(%q<pry-stack_explorer>, [">= 0"])
end
