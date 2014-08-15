require 'bundler/setup'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "praxis-mapper"
  gem.authors = "RightScale, Inc."
  gem.files = Dir.glob('lib/**/*.rb')
  # dependencies defined in Gemfile
end

Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'

desc "Run RSpec code examples with simplecov"
RSpec::Core::RakeTask.new do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

require 'right_support'

if require_succeeds?('right_develop')
  RightDevelop::CI::RakeTask.new
end

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
