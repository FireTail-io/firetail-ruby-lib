lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "firetail/version"

Gem::Specification.new do |spec|
  spec.name          = "firetail"
  spec.version       = Firetail::VERSION
  spec.authors       = ["Muhammad Nuzaihan"]
  spec.email         = ["zaihan@flitnetics.com"]

  spec.summary       = %q{Ruby library for firetail}
  spec.description   = %q{API security library that is designed for ruby}
  spec.homepage      = "https://www.firetail.io"
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/firetail-io/ruby"
  spec.metadata["changelog_uri"] = "https://github.com/firetail-io/ruby/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.18.1"

  # These gems are needed for firetail in production
  spec.add_dependency "async", "~> 1.30.3"
  spec.add_dependency "jwt", "~> 2.5"
  spec.add_dependency "json-schema", "~> 3.0.0"
  spec.add_dependency "committee_firetail", "~> 5.0.1"
end
