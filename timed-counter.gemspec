# Provide a simple gemspec so you can easily use your enginex
# project in your rails apps through git.
Gem::Specification.new do |s|
  s.name = "timed-counter"
  s.summary = "Simple Counters in Redis"
  s.description = "see above."
  s.files = Dir["{app,lib,config}/**/*"] + ["MIT-LICENSE", "Gemfile", "README"]
  s.version = "0.1.0"
  s.add_dependency("redis")
  s.add_dependency("nest")
end
