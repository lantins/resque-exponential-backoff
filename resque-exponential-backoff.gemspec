spec = Gem::Specification.new do |s|
    s.name              = 'resque-exponential-backoff'
    s.version           = '0.1.0'
    s.date              = Time.now.strftime('%Y-%m-%d')
    s.summary           = 'A resque plugin to add retry and exponential backoff functionality to jobs.'
    s.homepage          = 'http://github.com/lantins/resque-exponential-backoff'
    s.authors           = ['Luke Antins']
    s.email             = 'luke@lividpenguin.com'
    s.has_rdoc          = false
    
    s.files             = %w(LICENSE Rakefile README.md) + Dir.glob('{test,lib/**/*}')
    s.require_paths     = ['lib']
    
    s.add_dependency('resque', '~> 1.8.0')
    s.add_dependency('resque-scheduler', '~> 1.8.0')
    s.add_dependency('hashie', '~> 0.2.0')
    s.add_development_dependency('turn')
end