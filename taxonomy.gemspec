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
  s.homepage    = "https://github.com/sfaxon/taxonomy"
  s.summary     = "tagging with namespace and tree."
  s.description = "tagging with namespace and tree."

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.extra_rdoc_files = [
    "MIT-LICENSE",
    "README.rdoc"
  ]

  s.add_dependency "activerecord", ">= 3.0.0"
  # s.add_dependency "rails", ">= 3.1.3"

  s.add_development_dependency "sqlite3", "~> 1.3.0"
  s.add_development_dependency "rspec", ">= 2.0.0"
  
end

