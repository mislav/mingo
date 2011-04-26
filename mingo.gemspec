# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name    = 'mingo'
  gem.version = '0.2.0'
  gem.date    = Time.now.strftime('%Y-%m-%d')
  
  gem.add_dependency 'mongo', '>= 1.3'
  gem.add_dependency 'hashie', '>= 0.4.0'
  
  gem.summary = "Minimal Mongo"
  gem.description = "Mingo is a minimal document-object mapper for MongoDB."
  
  gem.authors  = ['Mislav Marohnić']
  gem.email    = 'mislav.marohnic@gmail.com'
  gem.homepage = 'http://github.com/mislav/mingo'
  
  gem.rubyforge_project = nil
  
  gem.files = Dir['Rakefile', '{bin,lib,test,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z`.split("\0")
end
