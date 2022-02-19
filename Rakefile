require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

task 'test:each_format' do
  formats = %w(
    rest_description
    openapi2
    openapi3
  )

  require 'term/ansicolor'
  print_status = -> (color, status, cmd) do
    STDERR.puts "#{Term::ANSIColor.color(color, status.ljust(7))} #{cmd}"
  end
  print_result = -> (result) do
    print_status.(*(result[:success] ? [:green, 'SUCCESS'] : [:red, 'FAILURE']), result[:cmd])
  end

  results = formats.map do |format|
    cmd = "SCORPIO_API_DESCRIPTION_FORMAT=#{format} bundle exec rake test"
    print_status.(:yellow, 'START', cmd)
    success = system(cmd)
    {success: success, cmd: cmd, exitstatus: $?.exitstatus}.tap(&print_result)
  end
  STDERR.puts
  STDERR.puts "#{Term::ANSIColor.cyan('SUMMARY')}:"
  results.each(&print_result)

  results.each { |result| exit(result[:exitstatus]) unless result[:success] }
end

task 'default' => 'test:each_format'

require 'gig'

ignore_files = %w(
  .github/**/*
  .gitignore
  Gemfile
  Rakefile
  test/**/*
  bin/documents_to_yml.rb
  resources/icons/**/*
).map { |glob| Dir.glob(glob, File::FNM_DOTMATCH) }.inject([], &:|)
Gig.make_task(gemspec_filename: 'scorpio.gemspec', ignore_files: ignore_files)
