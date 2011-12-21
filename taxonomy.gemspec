# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "taxonomy/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "taxonomy"
  s.version     = Taxonomy::VERSION
  s.authors     = ["Seth Faxon"]
  s.email       = ["seth.faxon@gmail.com"]
  s.homepage    = "https://github.com/marshill/taxonomy"
  s.summary     = "tagging with namespace and tree."
  s.description = "tagging with namespace and tree."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", ">= 3.0.0"
  # s.add_dependency "rails", ">= 3.1.3"

  s.add_development_dependency "sqlite3", "~> 1.3.0"
  s.add_development_dependency "rspec-rails", ">= 2.7.0"
  s.add_development_dependency "factory_girl_rails", ">= 1.4.0"
  
end

