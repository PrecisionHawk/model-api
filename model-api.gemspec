lib = File.expand_path("../lib", __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name = 'model-api'
  s.version = '0.8.10'
  s.summary = 'Create easy REST API\'s using metadata inside your ActiveRecord models'
  s.description = 'Ruby gem allowing Ruby on Rails developers to create REST API’s using ' \
      'metadata defined inside their ActiveRecord models.'
  s.licenses = ['Apache 2']
  s.authors = ['Matthew Mead']
  s.email = 'm.mead@precisionhawk.com'

  s.files = Dir.glob("{lib,spec,config}/**/*")
  s.files += %w(model-api.gemspec README.md)

  s.require_path = "lib"

  s.add_dependency "rails", "~> 4.0"
  s.add_dependency "open-api", "~> 0.8.4"

  s.add_development_dependency "rspec-rails", "~> 3.5", ">= 3.5.2"
end
