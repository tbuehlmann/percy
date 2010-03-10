Gem::Specification.new do |s|
  s.name = 'percy'
  s.version = '1.4.0'
  s.summary = '(DSL, EventMachine) IRC Bot Framework inspired by isaac'
  s.description = 'Percy is an IRC Bot framework inspired by isaac with various changes.'
  s.homepage = 'http://github.com/tbuehlmann/percy'
  s.date = '10.03.2010'
  
  s.author = 'Tobias Bühlmann'
  s.email = 'tobias.buehlmann@gmx.de'
  
  s.require_paths = ['lib']
  s.files = ['LICENSE',
             'README.md',
             'VERSION',
             'examples/github_blog.rb',
             'examples/is_online_checker.rb',
             'lib/percy.rb',
             'lib/percy/connection.rb',
             'lib/percy/formatting.rb',
             'lib/percy/irc.rb',
             'lib/percy/percylogger.rb',
             'percy.gemspec']
  
  s.has_rdoc = false
  s.add_dependency('eventmachine', '>= 0.12.10')
end
