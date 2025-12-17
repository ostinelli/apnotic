require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "appraisal"

RSpec::Core::RakeTask.new(:spec)

if !ENV["APPRAISAL_INITIALIZED"] && !ENV["CI"]
  task :default do
    sh "appraisal install && rake appraisal spec"
  end
else
  task default: :spec
end
