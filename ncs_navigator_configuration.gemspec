# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ncs_navigator/configuration/version"

Gem::Specification.new do |s|
  s.name        = "ncs_navigator_configuration"
  s.version     = NcsNavigator::Configuration::VERSION
  s.authors     = ["Rhett Sutphin"]
  s.email       = ["r-sutphin@northwestern.edu"]
  s.homepage    = ""
  s.summary     = %q{Common configuration elements for the NCS Navigator suite}
  s.description = %q{
    An internal component of the NCS Navigator suite, this gem provides a common view
    onto shared configuration elements.
  }

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'ncs_mdes', '~> 0.4'
  s.add_dependency 'inifile', '~> 0.4.1'
  s.add_dependency 'fastercsv', '~> 1.5'

  s.add_development_dependency 'rake', '~> 0.9.2'
  s.add_development_dependency 'rspec', '~> 2.6'
  s.add_development_dependency 'yard', '~> 0.7.2'
  s.add_development_dependency 'fakefs', '~> 0.3'
end
