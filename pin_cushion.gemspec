require 'rubygems'
Gem::Specification.new { |s|
  s.name = "pin_cushion"
  s.version = "2.0"
  s.date = "2011-06-06"
  s.author = "Ethan Waldo"
  s.homepage = "https://github.com/Dishwasha/pin_cushion"
  s.platform = Gem::Platform::RUBY
  s.summary = "Database-level Multitable Inheritance for Rails"
  s.files = Dir.glob("{lib,sample,test}/**/*")
  s.require_path = "lib/pin_cushion"
}
