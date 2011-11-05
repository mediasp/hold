require 'lib/persistence/version'

desc 'build a gem release and push it to dev'
task :release do
  sh 'gem build persistence.gemspec'
  sh "scp persistence-#{Persistence::VERSION}.gem dev.playlouder.com:/var/www/gems.playlouder.com/pending"
  sh "ssh dev.playlouder.com sudo include_gems.sh /var/www/gems.playlouder.com/pending"
end

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
  t.options = '--runner=specdox'
end

begin
  require 'yard'
  OTHER_PATHS = 'QUICK-START.md README.md'
  YARD::Rake::YardocTask.new do |t|
    t.files   = ['lib/**/*.rb', '-', 'QUICK-START.md', 'README.md']
  end
rescue NameError
  $stderr.puts('yard not installed, no yard task defined')
end