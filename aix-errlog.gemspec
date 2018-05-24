require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'aix-errlog'
  spec.version    = '2.0.1'
  spec.authors    = ['Taylor C. Richberger']
  spec.license    = 'MIT'
  spec.email      = 'tcr@absolute-performance.com'
  spec.homepage   = 'https://github.com/Taywee/aix-errlog'
  spec.summary    = 'Interface for the AIX error log facilities'
  spec.description = 'Ruby FFI interface for AIX errlog'
  spec.extra_rdoc_files = ['main.rdoc']
  spec.rdoc_options << '--main' << 'main.rdoc'
  spec.metadata = {
    'documentation_uri' => 'https://taywee.github.io/aix-errlog/',
  }
  spec.files      = %w(
    lib/aix/errlog.rb
    lib/aix/errlog/constants.rb
    lib/aix/errlog/entry.rb
    lib/aix/errlog/errlog.rb
    lib/aix/errlog/errors.rb
    lib/aix/errlog/lib.rb
    lib/aix/errlog/match.rb
  )

  spec.add_dependency('ffi', '~>1.9')
end
