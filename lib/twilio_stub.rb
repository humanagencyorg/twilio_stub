require "twilio_stub/version"
require "twilio_stub/app"
require "webmock"

module TwilioStub
  class Error < StandardError; end

  DB = Db.instance

  def self.boot
    App.boot_once
  end

  def self.twilio_host
    "http://localhost:#{App.port}"
  end

  def self.stub_requests
    WebMock::API.
      stub_request(:any, /twilio.com/).
      to_rack(App)
  end

  def self.clear_store
    DB.clear_all
  end

  def self.media_mapper
    @media_mapper ||= {}
  end
end
