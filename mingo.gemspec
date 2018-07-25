# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name    = 'mingo'
  gem.version = '0.4.5'
  
  gem.add_dependency 'mongo', ['>= 1.3', '< 2.0']
  
  gem.summary = "Minimal Mongo"
  gem.description = "Mingo is a minimal document-object mapper for MongoDB."
  
  gem.authors  = ['Mislav Marohnić']
  gem.email    = 'mislav.marohnic@gmail.com'
  gem.homepage = 'http://github.com/mislav/mingo'
  
  gem.files = Dir['Rakefile', '{bin,lib,test,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z`.split("\0")
end
