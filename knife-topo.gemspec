# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef/knife/topo/version'

Gem::Specification.new do |spec|
  spec.name          = "knife-topo"
  spec.version       = Knife::Topo::VERSION
  spec.authors       = ["Christine Draper"]
  spec.email         = ["christine_draper@thirdwaveinsights.com"]
  spec.summary       = "Knife plugin that to manage topologies of nodes"
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/christinedraper/knife-topo"
  spec.license       = "Apache License (2.0)"
  
  spec.files         = Dir.glob("{lib,test-repo}/**/*") +
  	Dir.glob("test-repo/.chef/*") +
    ['LICENSE', 'README.md', __FILE__]
  spec.require_paths = ["lib"]

end
