require 'bundler/setup'

require 'rspec/core'
require 'rspec/core/rake_task'
require 'bundler/gem_tasks'

desc "Run RSpec code examples with simplecov"
RSpec::Core::RakeTask.new do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
