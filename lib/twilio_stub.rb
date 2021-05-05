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

  def self.sent_sms_status_callback(sid:, status:)
    chatbot = DB.read("chatbot")
    ms = chatbot[:messaging_service]

    Net::HTTP.post_form(
      URI(ms[:callback_url]),
      {
        MessageSid: sid,
        MessageStatus: status,
      },
    )
  end

  def self.last_sent_message
    DB.read("sms_messages").last
  end

  def self.send_sms_response(from:, body:)
    inbound_url = DB.read("chatbot").dig(:messaging_service, :inbound_url)
    params = {
      Body: body,
      From: from,
    }

    Net::HTTP.post_form(
      URI(inbound_url),
      params,
    )
  end
end
