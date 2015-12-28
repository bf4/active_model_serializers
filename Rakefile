begin
  require 'simplecov'
rescue LoadError
end

require 'bundler/gem_tasks'

begin
  require 'rubocop'
  require 'rubocop/rake_task'
rescue LoadError
else
  Rake::Task[:rubocop].clear if Rake::Task.task_defined?(:rubocop)
  require 'rbconfig'
  # https://github.com/bundler/bundler/blob/1b3eb2465a/lib/bundler/constants.rb#L2
  windows_platforms = /(msdos|mswin|djgpp|mingw)/
  if RbConfig::CONFIG['host_os'] =~ windows_platforms
    desc 'No-op rubocop on Windows-- unsupported platform'
    task :rubocop do
      puts 'Skipping rubocop on Windows'
    end
  elsif defined?(::Rubinius)
    desc 'No-op rubocop to avoid rbx segfault'
    task :rubocop do
      puts 'Skipping rubocop on rbx due to segfault'
      puts 'https://github.com/rubinius/rubinius/issues/3499'
    end
  else
    Rake::Task[:rubocop].clear if Rake::Task.task_defined?(:rubocop)
    desc 'Execute rubocop'
    RuboCop::RakeTask.new(:rubocop) do |task|
      task.options = ['--rails', '--display-cop-names', '--display-style-guide']
      task.fail_on_error = true
    end
  end
end

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.ruby_opts = ['-r./test/test_helper.rb']
  t.verbose = true
end

task default: [:test, :rubocop]

desc 'CI test task'
task :ci => [:default]

require 'git'
require 'benchmark'
Rake::TestTask.new :benchmark_tests do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_benchmark.rb']
  t.ruby_opts = ['-r./test/test_helper.rb']
  t.verbose = true
end

task :benchmark do
  @git = Git.init('.')
  ref  = @git.current_branch

  actual = run_benchmark_spec ref
  master = run_benchmark_spec 'master'

  @git.checkout(ref)

  puts "\n\nResults ============================\n"
  puts "------------------------------------~> (Branch) MASTER"
  puts master
  puts "------------------------------------\n\n"

  puts "------------------------------------~> (Actual Branch) #{ref}"
  puts actual
  puts "------------------------------------"
end

def run_benchmark_spec(ref)
  @git.checkout(ref)
  response = Benchmark.realtime { Rake::Task['benchmark_tests'].invoke }
  Rake::Task['benchmark_tests'].reenable
  response
end
