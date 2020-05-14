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
### Twilio validation types

* Twilio.FIRST_NAME - starts with uppercase character, not include special symbols, not include spaces
* Twilio.LAST_NAME - starts with uppercase character, not include special symbols, not include spaces
* Twilio.EMAIL - starts with word + @ + first level domain
* Twilio.CITY - should be one of: `Kyiv`, `Odessa`, `Lviv`, `New York`, `Saint Louis`, `Washington`
* Twilio.COUNTRY - should be one of: `Ukraine`, `USA`, `United States of America`, `Great Britain`
* Twilio.US_STATE - should be one of: `MO`, `CA`, `NY`
* Twilio.ZIP_CODE - should contain 5-6 character long number
* Twilio.PHONE_NUMBER - should contain 10 character long number
* Twilio.YES_NO - should be one of: `yes`, `no`
