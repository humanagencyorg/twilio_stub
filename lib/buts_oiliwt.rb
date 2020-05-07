require "buts_oiliwt/version"
require "buts_oiliwt/app"

module ButsOiliwt
  class Error < StandardError; end

  TWILIO_HOST = "http://localhost:#{App.port}".freeze
  TWILIO_SDK_HOST = TWILIO_HOST
  TWILIO_EXECUTOR_URL = "#{TWILIO_SDK_HOST}/microservice".freeze

  DB = Db.instance

  def self.boot
    App.boot_once
  end

  def self.stub_requests
    stub_request(:any, /twilio.com/).to_rack(App)
  end

  def self.clear_all
    DB.clear_all
  end
end
