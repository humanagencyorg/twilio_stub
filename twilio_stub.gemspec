lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "twilio_stub/version"

Gem::Specification.new do |spec| # rubocop:disable Metrics/BlockLength
  spec.name          = "twilio_stub"
  spec.version       = TwilioStub::VERSION
  spec.authors       = ["Alex Beznos"]
  spec.email         = ["beznosa@yahoo.com"]

  spec.summary       = "Stub server for Twilio."
  spec.description   = "Gem adds ability to stub backend requests, " \
                       "js sdk requests and request for schema upload. " \
                       "When all this elements are stubbed it can be used as " \
                       "full featured chating engine."
  spec.homepage      = "https://github.com/humanagencyorg/twilio_stub"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.1"

  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = spec.homepage
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
          "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem
  # that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end

  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "pry", "~> 0.13"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", ">= 0.82"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-rspec"

  spec.add_runtime_dependency "async", "~> 1.26"
  spec.add_runtime_dependency "capybara"
  spec.add_runtime_dependency "faker", "~> 2.11"
  spec.add_runtime_dependency "jwt", "~> 2.2"
  spec.add_runtime_dependency "sinatra", "~> 3.0"
  spec.add_runtime_dependency "sinatra-cross_origin", "~> 0.4"
  spec.add_runtime_dependency "webmock"
  spec.metadata["rubygems_mfa_required"] = "true"
end
