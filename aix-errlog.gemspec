require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'aix-errlog'
  spec.version    = '0.0.1'
  spec.authors    = ['Taylor C. Richberger']
  spec.license    = 'MIT'
  spec.email      = 'tcr@absolute-performance.com'
  spec.homepage   = 'https://github.com/absperf/aix-errlog'
  spec.summary    = 'Interface for the AIX error log facilities'
  spec.description = 'Ruby FFI interface for AIX errlog'
  spec.files      = [
    'lib/aix/errlog.rb',
    'lib/aix/errlog/constants.rb',
    'lib/aix/errlog/entry.rb',
    'lib/aix/errlog/errlog.rb',
    'lib/aix/errlog/errors.rb',
    'lib/aix/errlog/match.rb',
    'lib/aix/errlog/lib.rb',
  ]

  spec.add_dependency('ffi', '~>1.9')
end
