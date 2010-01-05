Gem::Specification.new do |s|
  s.name = 'percy'
  s.version = '1.2.0'
  s.summary = '(DSL, EventMachine) IRC Bot Framework inspired by isaac'
  s.description = 'Percy is an IRC bot framework inspired by isaac with various changes.'
  s.homepage = 'http://github.com/tbuehlmann/percy'
  s.date = '05.01.2010'
  
  s.author = 'Tobias Bühlmann'
  s.email = 'tobias.buehlmann@gmx.de'
  
  s.require_paths = ['lib']
  s.files = ['lib/percy.rb', 'lib/percylogger.rb', 'README.md', 'LICENSE', 'VERSION']
  s.rubygems_version = '1.3.5'
  s.has_rdoc = false
  
  s.add_dependency('eventmachine', '>= 0.12.10')
end
