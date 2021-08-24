require_relative "./spec_helper"

require "twilio_stub/app"
require "jwt"
require "rack/test"
require "spec_helper"

RSpec.describe "Integration Spec" do
  module RSpecMixin
    include Rack::Test::Methods

    def app
      TwilioStub::App
    end
  end

  before do
    TwilioStub.clear_store

    RSpec.configure do |c|
      c.include RSpecMixin
    end
  end

  context "when a single assistant exists" do
    it "can read the last text message sent" do
      friendly_name = "X AE A-12"
      md5 = "123"
      unique_name = "#{friendly_name}_uniq"
      inbound_url = "https://www.fake.com"
      callback_url = "fake_callback_url"
      phone_number = "12345678"
      assistant_params = {
        "FriendlyName": friendly_name,
        "UniqueName": unique_name,
      }
      service_params = {
        "StatusCallback": callback_url,
        "InboundRequestUrl": inbound_url,
        "FriendlyName": friendly_name,
      }
      allow(Faker::Crypto).to receive(:md5).and_return(md5)

      stub_twilio(inbound_url: inbound_url)

      # create assistant
      result1 = post "/v1/Assistants", assistant_params

      assistant_sid = JSON.parse(result1.body)["sid"]

      # create messaging service
      result2 = post "/v1/Services", service_params

      msg_service_sid = JSON.parse(result2.body)["sid"]

      # send outbound messsage
      outbound_message_params = {
        assistant_sid: assistant_sid,
        MessagingServiceSid: msg_service_sid,
        To: phone_number,
        Body: "Hello",
      }
      post "/v1/Accounts/#{assistant_sid}/Messages.json",
           outbound_message_params

      # check the messages
      asst_message = TwilioStub.last_sent_message
      expect(asst_message[:body]).to eq("Hello")
    end
  end

  context "when multiple assistants exist" do
    it "should maintain text messages for each chatbot" do
      friendly_name = "X AE A-12"
      inbound_url = "https://www.fake.com"
      callback_url = "fake_callback_url"
      phone_number = "12345678"
      md5 = "123"
      allow(Faker::Crypto).to receive(:md5).and_return(md5)

      # Create assistants
      unique_name1 = "#{friendly_name}1"
      unique_name2 = "#{friendly_name}2"
      params1 = {
        "FriendlyName": friendly_name,
        "UniqueName": unique_name1,
      }
      params2 = {
        "FriendlyName": friendly_name,
        "UniqueName": unique_name2,
      }
      result1 = post "/v1/Assistants", params1
      result2 = post "/v1/Assistants", params2

      assistant_sid1 = JSON.parse(result1.body)["sid"]
      assistant_sid2 = JSON.parse(result2.body)["sid"]

      # create messaging service
      service_params = {
        "StatusCallback": callback_url,
        "InboundRequestUrl": inbound_url,
        "FriendlyName": friendly_name,
      }
      result1 = post "/v1/Services", service_params
      result2 = post "/v1/Services", service_params

      msg_service_sid1 = JSON.parse(result1.body)["sid"]
      msg_service_sid2 = JSON.parse(result2.body)["sid"]

      # send outbound messsages
      outbound_message_params1 = {
        assistant_sid: assistant_sid1,
        MessagingServiceSid: msg_service_sid1,
        To: phone_number,
        Body: "Hello",
      }
      outbound_message_params2 = {
        assistant_sid: assistant_sid2,
        MessagingServiceSid: msg_service_sid2,
        To: phone_number,
        Body: "Goodbye",
      }
      post "/v1/Accounts/#{assistant_sid1}/Messages.json",
           outbound_message_params1
      post "/v1/Accounts/#{assistant_sid2}/Messages.json",
           outbound_message_params2

      # check the messages
      asst1_message = TwilioStub.last_sent_message(sid: assistant_sid1)
      asst2_message = TwilioStub.last_sent_message(sid: assistant_sid2)

      expect(asst1_message[:body]).to eq("Hello")
      expect(asst2_message[:body]).to eq("Goodbye")
    end
  end

  def stub_twilio(inbound_url:)
    stub_request(
      :post,
      inbound_url,
    ).
      with(
        body: { "Body" => "Hi!", "From" => "+13144779816" },
        headers: {
          "Accept" => "*/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Content-Type" => "application/x-www-form-urlencoded",
          "Host" => "www.fake.com",
          "User-Agent" => "Ruby",
        },
      ).
      to_return(status: 200, body: "", headers: {})
  end
end
