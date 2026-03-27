# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/benchmark🦫_test.rb")
end

desc "Run the benchmark suite"
Rake::TestTask.new(:benchmark) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = ["test/benchmark🦫_test.rb"]
end

RuboCop::RakeTask.new(:rubocop)

desc "Lint Ruby and Markdown files"
task lint: :rubocop do
  sh "bundle exec mdl --style .mdl_style.rb README.md CHANGELOG.md docs/**/*.md"
end

task default: %i[test lint]

desc "Run the demo"
task :demo do
  ruby "bin/demo"
end

desc "Render README demo assets"
task :demo_assets do
  ruby "bin/render_demo_assets"
end
