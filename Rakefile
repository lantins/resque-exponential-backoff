require 'rake/testtask'
require 'fileutils'

task :default => :test

Rake::TestTask.new(:test) do |task|
    task.libs << 'lib' << 'test'
    task.test_files = FileList['test/*_test.rb']
    task.verbose = true
end