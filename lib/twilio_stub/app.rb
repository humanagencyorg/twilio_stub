# frozen_string_literal: true

require "sinatra/base"
require "sinatra/cross_origin"
require "jwt"
require "faker"

require "twilio_stub/dialog_resolver"
require "twilio_stub/bootable"

module TwilioStub
  class App < Sinatra::Base
    extend Bootable

    register Sinatra::CrossOrigin

    # Twilio js sdk
    get "/sdk/js/chat/v3.3/twilio-chat.min.js" do
      content_type "text/javascript"
      file_path = File.join(File.dirname(__FILE__), "/assets/sdk.js")
      status 200

      File.
        read(file_path).
        sub(/\#HOST\#/, TwilioStub.twilio_host)
    end

    # Twilio js api calls
    get "/js_api/channels/:channel_name" do |channel|
      cross_origin

      jwt = JWT.decode(params["token"], nil, false)
      key = "channel_#{channel}"

      DB.write(
        key,
        name: channel,
        customer_id: jwt.first.dig("grants", "identity"),
        chat_id: jwt.first.dig("grants", "chat", "service_sid"),
      )

      DB.write("#{key}_messages", [])

      status 200
    end

    get "/js_api/channels/:channel/messages" do |channel_name|
      cross_origin
      content_type "application/json"

      key = "channel_#{channel_name}_messages"

      { message: DB.read(key).last }.to_json
    end

    post "/js_api/channels/:channel/messages" do |channel_name|
      cross_origin
      channel_key = "channel_#{channel_name}"
      messages_key = "channel_#{channel_name}_messages"

      channel = DB.read(channel_key)
      messages = (DB.read(messages_key) || [])
      messages.push(
        body: JSON.parse(request.body.read)["message"],
        author: channel[:customer_id],
        sid: (0...8).map { ("a".."z").to_a[rand(26)] }.join,
      )

      DB.write(messages_key, messages)

      Async do |task|
        task.sleep(1)
        DialogResolver.
          new(channel_name, async: task, target: DB.read("target_task")).
          call
      end

      status 200
    end

    # Microservice routes stub
    post "/autopilot/update" do
      body = JSON.parse(request.body.read)
      schema = JSON.parse(body["schema"])

      DB.write("schema", schema)

      status 200
    end

    # Api requests
    post "/v2/:account_sid/:assistant_sid/custom/:session_id" do # rubocop:disable Metrics/BlockLength
      cross_origin
      message = params["Text"]

      channel_name = params[:session_id]
      channel_key = "channel_#{channel_name}"
      messages_key = "channel_#{channel_name}_messages"
      channel = DB.read(channel_key) || { customer_id: channel_name }
      messages = (DB.read(messages_key) || [])
      DB.write("channel_#{channel_name}_user_id", params["UserId"])
      messages.push(
        body: params["Text"],
        author: channel[:customer_id],
        sid: (0...8).map { ("a".."z").to_a[rand(26)] }.join,
      )

      DB.write(messages_key, messages)

      if message == "fallback"
        {
          current_task: "fallback",
        }.to_json
      else
        status 200

        DialogResolver.
          new(channel_name, target: params[:TargetTask]).
          call
        message = DB.read(messages_key).last[:body]
        {
          response: {
            says: [
              { text: message },
            ],
          },
        }.to_json
      end
    end

    get "/v2/Services/:assistant_id/Channels/:visitor_id" do
      DB.write("assistant_id", params[:assistant_id])
      DB.write("customer_id", params[:visitor_id])

      content_type "application/json"

      { unique_name: "hello", sid: "hello_sid" }.to_json
    end

    post "/v2/Services/:assistant_id/Channels/:channel_sid/Webhooks" do
      url = params["Configuration.Url"]
      task = url.match(/TargetTask=(.+)$/)[1]

      DB.write("target_task", task)

      content_type "application/json"
      status 200

      {}.to_json
    end

    post "/v1/Services" do
      sid = "MG#{Faker::Crypto.md5}"
      friendly_name = params["FriendlyName"]
      messaging_service = {
        sid: sid,
        friendly_name: friendly_name,
        callback_url: params["StatusCallback"],
        inbound_url: params["InboundRequestUrl"],
      }
      DB.write("messaging_service", messaging_service)

      content_type "application/json"
      status 200

      { sid: sid, friendly_name: friendly_name }.to_json
    end

    post "/v1/Services/:ms_sid/PhoneNumbers" do
      content_type "application/json"
      status 200

      {
        sid: params[:PhoneNumberSid],
      }.to_json
    end

    post "/v1/Assistants" do
      sid = "UA#{Faker::Crypto.md5}"
      friendly_name = params["FriendlyName"]
      unique_name = params["UniqueName"]

      DB.write(
        "chatbot",
        assistant_sid: sid,
        friendly_name: friendly_name,
        unique_name: unique_name,
      )

      DB.write(
        "schema",
        DEFAULT_SCHEMA.merge(
          "uniqueName" => unique_name,
          "friendlyName" => friendly_name,
        ),
      )

      content_type "application/json"
      status 200

      { sid: sid, unique_name: unique_name }.to_json
    end

    post "/v1/Assistants/:assistant_sid" do
      sid = params[:assistant_sid]
      development_stage = params["DevelopmentStage"]
      chatbot = DB.read("chatbot")
      chatbot[:development_stage] = development_stage

      DB.write("chatbot", chatbot)

      status 200

      {
        sid: sid,
        development_stage: development_stage,
      }.to_json
    end

    post "/v1/Assistants/:assistant_sid/StyleSheet" do
      schema = DB.read("schema")
      DB.write(
        "schema",
        schema.merge("styleSheet" => JSON.parse(params[:StyleSheet])),
      )

      status 200
      {}.to_json
    end

    post "/v1/Assistants/:assistant_sid/Defaults" do
      schema = DB.read("schema")
      DB.write(
        "schema",
        schema.merge("defaults" => JSON.parse(params[:Defaults])),
      )

      status 200
      {}.to_json
    end

    post "/v1/Assistants/:assistant_sid/Tasks" do
      sid = "UD#{Faker::Crypto.md5}"
      schema = DB.read("schema")
      task = DEFAULT_TASK_SCHEMA.merge(
        "sid" => sid,
        "uniqueName" => params[:UniqueName],
        "actions" => JSON.parse(params[:Actions]),
      )
      schema["tasks"].push(task)

      DB.write("schema", schema)

      status 200
      { sid: sid }.to_json
    end

    delete "/v1/Assistants/:assistant_sid/Tasks/:task_sid" do
      schema = DB.read("schema")
      tasks = schema["tasks"].reject do |task|
        task["sid"] == params[:task_sid]
      end
      schema["tasks"] = tasks
      DB.write("schema", schema)

      status 200
      {}.to_json
    end

    post "/v1/Assistants/:assistant_sid/Tasks/:task_sid/Samples" do
      sid = "UF#{Faker::Crypto.md5}"
      schema = DB.read("schema")
      schema["tasks"].each do |task|
        if task["sid"] == params["task_sid"]
          task["samples"].push({
                                 "sid" => sid,
                                 "Language" => params["Language"],
                                 "TaggedText" => params["TaggedText"],
                               })
        end
      end
      DB.write("schema", schema)

      status 200
      { sid: sid }.to_json
    end

    delete "/v1/Assistants/:assistant_sid/Tasks/:task_sid/Samples/:sample_sid" do # rubocop:disable Layout/LineLength
      schema = DB.read("schema")
      schema["tasks"].each do |task|
        if task["sid"] == params["task_sid"]
          samples = task["samples"].reject do |sample|
            sample["sid"] == params[:sample_sid]
          end

          task["samples"] = samples
        end
      end
      DB.write("schema", schema)

      status 200
      {}.to_json
    end

    post "/v1/Assistants/:assistant_sid/ModelBuilds" do
      status 200
      {}.to_json
    end

    post "/:api_version/Accounts/:account_id/IncomingPhoneNumbers.json" do
      Faker::Config.locale = "en-US"
      phone_number = Faker::PhoneNumber.cell_phone_in_e164
      phone_number_sid = "PN#{Faker::Crypto.md5}"

      numbers = DB.read("phone_numbers") || []
      numbers.push(
        phone_number: phone_number,
        phone_number_sid: phone_number_sid,
      )
      DB.write("phone_numbers", numbers)

      content_type "application/json"
      status 200

      {
        sid: phone_number_sid,
        phone_number: phone_number,
      }.to_json
    end

    post "/:api_version/Accounts/:assistant_sid/Messages.json" do
      message_sid = "MS#{Faker::Crypto.md5}"
      messages = DB.read("sms_messages")
      messages ||= []
      messages.push(
        sid: message_sid,
        body: params[:Body],
        ms_sid: params[:MessagingServiceSid],
        to: params[:To],
        status: "delivered",
        num_media: "0",
        num_segments: "1",
        assistant_sid: params[:assistant_sid],
      )
      DB.write("sms_messages", messages)

      content_type "application/json"
      status 200

      {
        sid: message_sid,
      }.to_json
    end

    post "/:api_version/Accounts.json" do
      account_sid = "AC#{Faker::Crypto.md5}"

      content_type "application/json"
      status 200

      {
        sid: account_sid,
      }.to_json
    end

    get "/:api_version/Accounts/:assistant_sid/Messages/:message_sid.json" do
      message = DB.read("sms_messages").detect do |m|
        m[:sid] == params[:message_sid]
      end

      content_type "application/json"
      status 200

      message.slice(:sid, :status, :num_media, :num_segments).to_json
    end

    get "/:api_version/Assistants/:assistant_sid/Queries.json" do
      DB.write("assistant_id", params[:assistant_id])

      content_type "application/json"
      status 200

      { results: { fields: [{ name: "fake_name",
                              type: "fake_type" }] } }.to_json
    end
  end
end
