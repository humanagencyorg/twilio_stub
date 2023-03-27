require_relative "./spec_helper"

require "twilio_stub/app"
require "twilio_stub/db"

RSpec.describe TwilioStub do
  describe "DEFAULT_SCHEMA" do
    it "returns schema" do
      expected = {
        "uniqueName" => "",
        "friendlyName" => "",
        "logQueries" => true,
        "defaults" => {},
        "fieldTypes" => [],
        "tasks" => [],
        "styleSheet" => {},
      }

      expect(described_class::DEFAULT_SCHEMA).to eq(expected)
    end
  end

  describe "DEFAULT_TASK_SCHEMA" do
    it "returns schema" do
      expected = {
        "uniqueName" => "",
        "sid" => "",
        "fields" => [],
        "actions" => {},
        "samples" => [],
      }

      expect(described_class::DEFAULT_TASK_SCHEMA).to eq(expected)
    end
  end

  describe ".media_mapper" do
    it "allows to set and get media_mapper keys" do
      TwilioStub.media_mapper[:foo] = :bar

      expect(TwilioStub.media_mapper[:foo]).to eq(:bar)
    end
  end

  describe ".boot" do
    it "calls App.boot_once" do
      allow(TwilioStub::App).to receive(:boot_once)

      described_class.boot

      expect(TwilioStub::App).to have_received(:boot_once)
    end
  end

  describe ".twilio_host" do
    it "returns localhost with App's port" do
      allow(TwilioStub::App).to receive(:port).and_return(9292)

      expect(described_class.twilio_host).to eq("http://localhost:9292")
    end
  end

  describe ".stub_requests" do
    it "calls webmock to stub twilio requests" do
      webmock = class_double(WebMock::API).as_stubbed_const
      webmock_instance = double("WebMock::API instance")

      allow(webmock).
        to receive(:stub_request).
        with(:any, /twilio.com/).
        and_return(webmock_instance)
      allow(webmock_instance).
        to receive(:to_rack).
        with(TwilioStub::App)

      described_class.stub_requests

      expect(webmock).
        to have_received(:stub_request).
        with(:any, /twilio.com/)
      expect(webmock_instance).
        to have_received(:to_rack).
        with(TwilioStub::App)
    end
  end

  describe ".clear_store" do
    it "calls DB to clear it" do
      allow(TwilioStub::DB).to receive(:clear_all)

      described_class.clear_store

      expect(TwilioStub::DB).to have_received(:clear_all)
    end
  end

  describe ".sent_sms_status_callback" do
    it "makes request to messaging service callback url" do
      sid = "fake_sid"
      status = "fake_status"
      callback_url = "http://fake_url.com"
      ms = {
        callback_url:,
      }
      expected_body = {
        MessageSid: sid,
        MessageStatus: status,
      }
      allow(TwilioStub::DB).
        to receive(:read).
        with("messaging_service").
        and_return(ms)
      stub_request(:post, callback_url).
        to_return(status: 200)

      described_class.sent_sms_status_callback(sid:, status:)

      expect(WebMock).to have_requested(:post, callback_url).
        with(body: expected_body)
    end
  end

  describe ".last_sent_message" do
    it "returns last message from sms_messages" do
      first_message = "first message"
      last_message = "last_message"
      messages = [first_message, last_message]

      allow(TwilioStub::DB).
        to receive(:read).
        with("sms_messages").
        and_return(messages)

      result = described_class.last_sent_message

      expect(result).to eq(last_message)
    end

    context "when no message have been sent" do
      it "returns nil" do
        allow(TwilioStub::DB).
          to receive(:read).
          with("sms_messages").
          and_return(nil)

        result = described_class.last_sent_message

        expect(result).to eq(nil)
      end
    end
  end

  describe ".sent_messages" do
    it "returns all messages sent" do
      first_message = "first message"
      last_message = "last_message"
      messages = [first_message, last_message]

      allow(TwilioStub::DB).
        to receive(:read).
        with("sms_messages").
        and_return(messages)

      result = described_class.sent_messages

      expect(result.count).to eq(2)
      expect(result).to include(first_message)
      expect(result).to include(last_message)
    end
  end

  describe ".send_sms_response" do
    it "calls inbound url with proper params" do
      md5 = "fake_md_5"
      inbound_url = "http://fake.url"
      ms = { inbound_url: }
      from = "12345678901"
      body = "message body"
      request_body = {
        Body: body,
        From: from,
        SmsMessageSid: "MS#{md5}",
      }

      allow(TwilioStub::DB).to receive(:read).with("messaging_service").
        and_return(ms)
      allow(TwilioStub::DB).to receive(:read).with("sms_messages").
        and_return([])
      allow(TwilioStub::DB).to receive(:write)
      allow(Faker::Crypto).to receive(:md5).and_return(md5)
      stub_request(:post, inbound_url).
        to_return(status: 200)

      described_class.send_sms_response(from:, body:)

      expect(WebMock).to have_requested(:post, inbound_url).
        with(body: request_body)
    end

    it "creates sms_messages in DB" do
      md5 = "fake_md_5"
      inbound_url = "http://fake.url"
      ms = { sid: "fake_message_sid", inbound_url: }
      from = "12345678901"
      body = "message body"
      expected_sms = {
        sid: "MS#{md5}",
        body:,
        ms_sid: ms[:sid],
        from:,
        status: "delivered",
        num_media: "0",
        num_segments: "1",
      }

      allow(TwilioStub::DB).to receive(:read).with("messaging_service").
        and_return(ms)
      allow(TwilioStub::DB).to receive(:read).with("sms_messages").
        and_return([])
      allow(TwilioStub::DB).to receive(:write)
      allow(Faker::Crypto).to receive(:md5).and_return(md5)
      stub_request(:post, inbound_url).
        to_return(status: 200)

      described_class.send_sms_response(from:, body:)

      expect(TwilioStub::DB).to have_received(:write).
        with("sms_messages", [expected_sms])
    end
  end
end
