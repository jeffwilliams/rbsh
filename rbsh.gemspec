Gem::Specification.new do |s|
  s.name = %q{rbsh}
  s.version = "0.0.1"
  s.date = %q{2013-12-21}
  s.authors = ["Jeff Williams"]
  s.email = %q{jeff.williams@bridgewatersys.com}
  s.summary = %q{Ruby shell}
  s.description = %q{A ruby shell}
  s.files = Dir['bin/*'] + Dir['lib/**/*.rb']
  s.has_rdoc = false
  s.executables = ["rbsh"]

  s.add_runtime_dependency "rb-readline", "~> 0.5"
  s.add_runtime_dependency "ruby-termios", "~> 0.9"
end
