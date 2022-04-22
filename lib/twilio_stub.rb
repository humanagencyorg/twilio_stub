require "twilio_stub/version"
require "twilio_stub/app"
require "webmock"
require "faker"

module TwilioStub
  class Error < StandardError; end

  DB = Db.instance
  DEFAULT_SCHEMA = {
    "uniqueName" => "",
    "friendlyName" => "",
    "logQueries" => true,
    "defaults" => {},
    "fieldTypes" => [],
    "tasks" => [],
    "styleSheet" => {},
  }.freeze
  DEFAULT_TASK_SCHEMA = {
    "sid" => "",
    "uniqueName" => "",
    "fields" => [],
    "actions" => {},
    "samples" => [],
  }.freeze

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
    ms = DB.read("messaging_service")

    Net::HTTP.post_form(
      URI(ms[:callback_url]),
      {
        MessageSid: sid,
        MessageStatus: status,
      },
    )
  end

  def self.last_sent_message
    DB.read("sms_messages")&.last
  end

  def self.sent_messages
    DB.read("sms_messages")
  end

  def self.send_sms_response(from:, body:)
    mservice = DB.read("messaging_service")
    message_sid = "MS#{Faker::Crypto.md5}"
    messages = DB.read("sms_messages")
    messages ||= []
    messages.push(
      sid: message_sid,
      body: body,
      ms_sid: mservice[:sid],
      from: from,
      status: "delivered",
      num_media: "0",
      num_segments: "1",
    )
    DB.write("sms_messages", messages)

    params = {
      Body: body,
      From: from,
      SmsMessageSid: message_sid,
    }

    Net::HTTP.post_form(URI(mservice[:inbound_url]), params)
  end

  def self.create_sample_for_task(task_sid:, tagged_text:, language: "en-US")
    schema = TwilioStub::DB.read("schema")
    sample = {
      "sid" => "UF#{Faker::Crypto.md5}",
      "Language" => language,
      "TaggedText" => tagged_text,
    }

    schema["tasks"].
      detect { |task| task["sid"] == task_sid }.
      fetch("samples", []).
      push(sample)

    TwilioStub::DB.write("schema", schema)

    sample
  end

  def self.fetch_task_samples(task_sid:)
    tasks = TwilioStub::DB.read("schema")["tasks"]
    return if tasks.nil? || tasks.empty?

    task = tasks.detect { |item| item["sid"] == task_sid }
    return if task.nil?

    task["samples"]
  end
end
