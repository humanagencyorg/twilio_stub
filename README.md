# TwilioStub

This gem allow to stub backend, fronend requests to twilio and js sdk. It should be used in testing environment only.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'twilio_stub'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install twilio_stub

## Usage

Rspec callbacks should be added in such way:

```
RSpec.configure do |config|
  config.before(:suite) do
    ButsOiliwt.boot
  end

  config.around(:each) do |example|
    ButsOiliwt.stub_requests
    ButsOiliwt.clear_store

    ClimateControl.modify(
      TWILIO_SDK_HOST: ButsOiliwt.twilio_host,
      TWILIO_EXECUTOR_URL: ButsOiliwt.twilio_host,
    ) do
      example.run
    end

    ButsOiliwt.clear_store
  end
```
