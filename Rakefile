$gemfile_name = nil
  
task :default => [:makegem]
      
task :makegem do
  system "gem build rbsh.gemspec"
end

task :run do
  exec "ruby1.9.1 -I lib/ bin/rbsh"
end
