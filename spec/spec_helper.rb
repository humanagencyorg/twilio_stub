ENV["RACK_ENV"] = "test"

require "bundler/setup"
require "webmock/rspec"
require "simplecov"

SimpleCov.start do
  add_filter %r{spec}
end

require "twilio_stub"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.after(:each) do
    TwilioStub::DB.clear_all
  end
end
