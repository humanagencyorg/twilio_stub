require "buts_oiliwt/version"
require "buts_oiliwt/app"
require "webmock"

module ButsOiliwt
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
end
