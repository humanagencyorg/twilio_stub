require "jwt"
require "rack/test"
require "spec_helper"

RSpec.describe TwilioStub::App do
  module RSpecMixin # rubocop:disable Lint/ConstantDefinitionInBlock
    include Rack::Test::Methods

    def app
      described_class
    end
  end

  before do
    TwilioStub.clear_store

    RSpec.configure do |c|
      c.include RSpecMixin
    end
  end

  describe "requests" do
    describe "GET /sdk/js/chat/v3.3/twilio-chat.min.js" do
      it "returns status 200" do
        get "/sdk/js/chat/v3.3/twilio-chat.min.js"

        expect(last_response.status).to eq(200)
      end

      it "returns content type javascript" do
        get "/sdk/js/chat/v3.3/twilio-chat.min.js"

        expect(last_response.content_type).
          to eq("text/javascript;charset=utf-8")
      end

      it "sets host to TwilioStub.twilio_host" do
        fake_host = "localhost:1234"
        allow(TwilioStub).to receive(:twilio_host).and_return(fake_host)
        get "/sdk/js/chat/v3.3/twilio-chat.min.js"

        expect(last_response.body).to include("host: \"#{fake_host}\"")
      end
    end

    describe "GET /js_api/channels/:channel_name" do
      it "returns status 200" do
        channel_name = "new_channel"
        channel_info = {
          grants: {
            identity: "visitor_1",
            chat: {
              service_sid: "sid",
            },
          },
        }
        token = JWT.encode(channel_info, nil, "none")
        params = {
          token: token,
        }

        get "/js_api/channels/#{channel_name}", params

        expect(last_response.status).to eq(200)
      end

      it "creates a channel" do
        channel_name = "new_channel"
        identity = "identity"
        service_sid = "123"
        channel_info = {
          grants: {
            identity: identity,
            chat: {
              service_sid: service_sid,
            },
          },
        }
        token = JWT.encode(channel_info, nil, "none")
        params = {
          token: token,
        }

        get "/js_api/channels/#{channel_name}", params

        channel_record = TwilioStub::DB.read("channel_#{channel_name}")
        expect(channel_record[:name]).to eq(channel_name)
        expect(channel_record[:customer_id]).to eq(identity)
        expect(channel_record[:chat_id]).to eq(service_sid)
      end

      it "creates messages array for channel" do
        channel_name = "new_channel"
        channel_info = {
          grants: {
            identity: "visitor_1",
            chat: {
              service_sid: "sid",
            },
          },
        }
        token = JWT.encode(channel_info, nil, "none")
        params = {
          token: token,
        }

        get "/js_api/channels/#{channel_name}", params

        db_key = "channel_#{channel_name}_messages"
        messages = TwilioStub::DB.read(db_key)

        expect(messages).to eq([])
      end
    end

    describe "GET /js_api/channels/:channel/messages" do
      it "returns status 200" do
        channel_name = "channel"
        db_key = "channel_#{channel_name}_messages"
        TwilioStub::DB.write(db_key, ["message"])

        get "/js_api/channels/#{channel_name}/messages"

        expect(last_response.status).to eq(200)
      end

      it "returns last message" do
        channel_name = "channel"
        messages = ["fisrt", "second", "last"]
        db_key = "channel_#{channel_name}_messages"
        TwilioStub::DB.write(db_key, messages)

        get "/js_api/channels/#{channel_name}/messages"

        response = JSON.parse(last_response.body)

        expect(response["message"]).to eq(messages.last)
      end
    end

    describe "POST /js_api/channels/:channel/messages" do
      it "returns status 200" do
        channel_name = "chanel"
        request_body = {
          message: "hello",
        }.to_json
        headers = { "CONTENT_TYPE" => "application/json" }
        db_key = "channel_#{channel_name}"
        TwilioStub::DB.write(db_key, {})

        stub_dialog_resolver

        post "/js_api/channels/#{channel_name}/messages", request_body, headers

        expect(last_response.status).to eq(200)
      end

      it "calls DialogResolver" do
        channel_name = "chanel"
        request_body = {
          message: "hello",
        }.to_json
        headers = { "CONTENT_TYPE" => "application/json" }
        db_key = "channel_#{channel_name}"
        TwilioStub::DB.write(db_key, {})
        TwilioStub::DB.write("target_task", "fake_task_name")

        dialog_resolver = stub_dialog_resolver

        post "/js_api/channels/#{channel_name}/messages", request_body, headers

        expect(TwilioStub::DialogResolver).
          to have_received(:new).
          with(channel_name, hash_including(target: "fake_task_name"))
        expect(dialog_resolver).to have_received(:call)
      end

      it "saves message with metadata to db" do
        channel_name = "chanel"
        message = "message"
        request_body = {
          message: message,
        }.to_json
        headers = { "CONTENT_TYPE" => "application/json" }
        channel_db_key = "channel_#{channel_name}"
        customer_id = "123"
        channel_data = {
          customer_id: customer_id,
        }
        message_db_key = "channel_#{channel_name}_messages"
        TwilioStub::DB.write(channel_db_key, channel_data)
        TwilioStub::DB.write(message_db_key, [])

        stub_dialog_resolver

        post "/js_api/channels/#{channel_name}/messages", request_body, headers

        last_message = TwilioStub::DB.read(message_db_key).last

        expect(last_message[:body]).to eq(message)
        expect(last_message[:author]).to eq(customer_id)
      end
    end

    describe "POST /v2/:account_sid/:assistant_sid/custom/:session_sid" do
      it "returns a 200" do
        account_sid = "AC123"
        assistant_sid = "UA123"
        session_sid = "sms_chat_3"
        message = "Hello"
        user_id = 3
        params = {
          Text: message,
          UserId: user_id,
        }

        stub_dialog_resolver

        post "/v2/#{account_sid}/#{assistant_sid}/custom/#{session_sid}", params

        expect(last_response.status).to eq(200)
      end

      it "returns last message from messages array" do
        account_sid = "AC123"
        assistant_sid = "UA123"
        session_sid = "sms_chat_3"
        message = "Hello"
        user_id = 3
        last_message = "Last mesage"

        params = {
          Text: message,
          UserId: user_id,
        }

        dialog_resolver = instance_double(TwilioStub::DialogResolver)
        allow(TwilioStub::DialogResolver).
          to receive(:new).
          and_return(dialog_resolver)
        allow(dialog_resolver).
          to receive(:call) do
            messages_key = "channel_#{session_sid}_messages"
            TwilioStub::DB.write(messages_key, [{ body: last_message }])
          end

        post "/v2/#{account_sid}/#{assistant_sid}/custom/#{session_sid}", params

        parsed = JSON.parse(last_response.body)

        expect(parsed.dig("response", "says", 0, "text")).to eq(last_message)
      end

      it "passes targeted task to DialogResolver" do
        account_sid = "AC123"
        assistant_sid = "UA123"
        session_sid = "sms_chat_3"
        task_name = "fake_targeted_task"
        message = "Hello"
        user_id = 3
        last_message = "Last mesage"

        params = {
          Text: message,
          UserId: user_id,
          TargetTask: task_name,
        }

        dialog_resolver = instance_double(TwilioStub::DialogResolver)
        allow(TwilioStub::DialogResolver).
          to receive(:new).
          and_return(dialog_resolver)
        allow(dialog_resolver).
          to receive(:call) do
            messages_key = "channel_#{session_sid}_messages"
            TwilioStub::DB.write(messages_key, [{ body: last_message }])
          end

        post "/v2/#{account_sid}/#{assistant_sid}/custom/#{session_sid}", params

        expect(TwilioStub::DialogResolver).to have_received(:new).
          with(session_sid, target: task_name, body: message)
      end

      context "when the message mentions fallback" do
        it "should return the fallback JSON" do
          account_sid = "AC123"
          assistant_sid = "UA123"
          session_sid = "sms_chat_3"
          message = "fallback"
          user_id = 3
          dialogue_sid = "DC123"
          allow(Faker::Crypto).to receive(:md5).and_return(dialogue_sid)

          params = {
            Text: message,
            UserId: user_id,
          }
          post "/v2/#{account_sid}/#{assistant_sid}/custom/#{session_sid}",
               params

          parsed = JSON.parse(last_response.body)
          expect(parsed["current_task"]).to eq("fallback")
          expect(parsed.dig("response", "says", 0, "text")).to be_nil
        end
      end
    end

    describe "POST autopilot/update" do
      it "returns 200" do
        headers = { "CONTENT_TYPE" => "application/json" }

        post "autopilot/update", { schema: {}.to_json }.to_json, headers

        expect(last_response.status).to eq(200)
      end

      it "writes schema to DB" do
        schema = { "key_1" => "value" }
        headers = { "CONTENT_TYPE" => "application/json" }

        post "autopilot/update", { schema: schema.to_json }.to_json, headers

        db_schema = TwilioStub::DB.read("schema")

        expect(db_schema).to eq(schema)
      end
    end

    describe "GET /v2/Services/:assistant_id/Channels/:visitor_id" do
      it "returns status 200" do
        get "/v2/Services/123/Channels/123"

        expect(last_response.status).to eq(200)
      end

      it "writes metadata to db" do
        assistant_id = 123
        visitor_id = 456

        get "/v2/Services/#{assistant_id}/Channels/#{visitor_id}"

        expect(TwilioStub::DB.read("assistant_id")).to eq(assistant_id.to_s)
        expect(TwilioStub::DB.read("customer_id")).to eq(visitor_id.to_s)
      end

      it "returns fake json" do
        expected_response = { "unique_name" => "hello", "sid" => "hello_sid" }

        get "/v2/Services/123/Channels/123"

        response = JSON.parse(last_response.body)

        expect(response).to eq(expected_response)
      end
    end

    describe "POST /v2/Services/:assistant_id/Channels/:channel_sid/Webhooks" do
      it "returns status and empty json" do
        url = "https://hello.com/fake?TargetTask=task"

        post(
          "/v2/Services/AC123/Channels/CH123/Webhooks",
          "Configuration.Url" => url,
        )

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq({})
      end

      it "saves target task to db" do
        url = "https://hello.com/fake?TargetTask=super_fake_task"

        post(
          "/v2/Services/AC123/Channels/CH123/Webhooks",
          "Configuration.Url" => url,
        )

        expect(TwilioStub::DB.read("target_task")).to eq("super_fake_task")
      end
    end

    describe "POST /v1/Services" do
      it "updates chatbot with messaging service" do
        sid_md = "fake_sid_md"
        full_sid = "MG#{sid_md}"
        friendly_name = "fake_friendly_name"
        callback_url = "fake_callback_url"
        inbound_url = "fake_inbound_url"
        params = {
          FriendlyName: friendly_name,
          StatusCallback: callback_url,
          InboundRequestUrl: inbound_url,
        }
        allow(Faker::Crypto).to receive(:md5).and_return(sid_md)

        TwilioStub::DB.write("chatbot", {})

        post "/v1/Services", params

        ms = TwilioStub::DB.read("messaging_service")
        expect(ms[:friendly_name]).to eq(friendly_name)
        expect(ms[:sid]).to eq(full_sid)
        expect(ms[:inbound_url]).to eq(inbound_url)
        expect(ms[:callback_url]).to eq(callback_url)
      end

      it "returns messaging service sid and friendly_name" do
        sid_md = "fake_sid_md"
        full_sid = "MG#{sid_md}"
        friendly_name = "fake_friendly_name"
        callback_url = "fake_callback_url"
        inbound_url = "fake_inbound_url"
        params = {
          FriendlyName: friendly_name,
          StatusCallback: callback_url,
          InboundRequestUrl: inbound_url,
        }
        allow(Faker::Crypto).to receive(:md5).and_return(sid_md)

        TwilioStub::DB.write("chatbot", {})

        post "/v1/Services", params

        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response["sid"]).to eq(full_sid)
        expect(response["friendly_name"]).to eq(friendly_name)
      end
    end

    describe "POST /v1/Services/:ms_sid/PhoneNumbers" do
      it "returns phone number sid from params" do
        phone_number_sid = "fake_phone_number_sid"
        params = { PhoneNumberSid: phone_number_sid }

        post "/v1/Services/MSSID/PhoneNumbers", params

        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response["sid"]).to eq(phone_number_sid)
      end
    end

    describe "POST /v1/Assistants" do
      it "returns 200" do
        post "/v1/Assistants"

        expect(last_response.status).to eq(200)
      end

      it "writes assistant data to db" do
        friendly_name = "X AE A-12"
        md5 = "123"
        sid = "UA#{md5}"
        unique_name = "#{friendly_name}1"
        params = {
          FriendlyName: friendly_name,
          UniqueName: unique_name,
        }
        expected_schema_keys = %w[
          uniqueName
          friendlyName
          logQueries
          defaults
          fieldTypes
          tasks
          styleSheet
        ]

        allow(Faker::Crypto).to receive(:md5).and_return(md5)

        post "/v1/Assistants", params

        chatbot = TwilioStub::DB.read("chatbot")

        expect(chatbot[:friendly_name]).to eq(friendly_name)
        expect(chatbot[:assistant_sid]).to eq(sid)
        expect(chatbot[:unique_name]).to eq(unique_name)

        schema = TwilioStub::DB.read("schema")
        expect(schema.keys).to match_array(expected_schema_keys)
        expect(schema["uniqueName"]).to eq(unique_name)
        expect(schema["friendlyName"]).to eq(friendly_name)
        expect(schema["logQueries"]).to eq(true)
        expect(schema["defaults"]).to eq({})
        expect(schema["styleSheet"]).to eq({})
        expect(schema["fieldTypes"]).to eq([])
        expect(schema["tasks"]).to eq([])
      end

      it "returns assistant_sid and unique name" do
        friendly_name = "X AE A-12"
        md5 = "123"
        sid = "UA#{md5}"
        unique_name = "#{friendly_name}1"
        params = {
          FriendlyName: friendly_name,
          UniqueName: unique_name,
        }

        allow(Faker::Crypto).to receive(:md5).and_return(md5)

        post "/v1/Assistants", params

        response = JSON.parse(last_response.body)

        expect(response["sid"]).to eq(sid)
        expect(response["unique_name"]).to eq(unique_name)
      end
    end

    describe "POST /v1/Assistants/:assistant_sid" do
      it "returns 200" do
        assistant_sid = "AC123"
        development_stage = "fake_dev_stage"
        params = {
          DevelopmentStage: development_stage,
        }
        TwilioStub::DB.write("chatbot", {})

        post "/v1/Assistants/#{assistant_sid}", params

        expect(last_response.status).to eq(200)
      end

      it "returns the assistant hash" do
        assistant_sid = "AC123"
        development_stage = "fake_dev_stage"
        params = {
          DevelopmentStage: development_stage,
        }
        TwilioStub::DB.write("chatbot", {})

        post "/v1/Assistants/#{assistant_sid}", params

        parsed = JSON.parse(last_response.body)
        expect(parsed).to eq(
          "sid" => assistant_sid,
          "development_stage" => development_stage,
        )
      end

      it "writes updated assistant data to db" do
        assistant_sid = "AC123"
        development_stage = "fake_dev_stage"
        TwilioStub::DB.write("chatbot", {})
        params = {
          DevelopmentStage: development_stage,
        }

        post "/v1/Assistants/#{assistant_sid}", params

        chatbot = TwilioStub::DB.read("chatbot")
        expect(chatbot[:development_stage]).to eq(development_stage)
      end
    end

    describe "POST /v1/Assistants/:assistant_sid/StyleSheet" do
      it "returns 200" do
        assistant_sid = "AC123"
        stylesheet = {
          "some" => {
            "fake" => [{ "style" => "sheet" }],
          },
        }
        params = {
          StyleSheet: stylesheet.to_json,
        }
        TwilioStub::DB.write("schema", TwilioStub::DEFAULT_SCHEMA)

        post "/v1/Assistants/#{assistant_sid}/StyleSheet", params

        expect(last_response.status).to eq(200)
      end

      it "returns empty hash" do
        assistant_sid = "AC123"
        stylesheet = {
          "some" => {
            "fake" => [{ "style" => "sheet" }],
          },
        }
        params = {
          StyleSheet: stylesheet.to_json,
        }
        TwilioStub::DB.write("schema", TwilioStub::DEFAULT_SCHEMA)

        post "/v1/Assistants/#{assistant_sid}/StyleSheet", params

        parsed = JSON.parse(last_response.body)
        expect(parsed).to eq({})
      end

      it "writes stylesheet to db" do
        assistant_sid = "AC123"
        stylesheet = {
          "some" => {
            "fake" => [{ "style" => "sheet" }],
          },
        }
        params = {
          StyleSheet: stylesheet.to_json,
        }
        TwilioStub::DB.write("schema", TwilioStub::DEFAULT_SCHEMA)

        post "/v1/Assistants/#{assistant_sid}/StyleSheet", params

        schema = TwilioStub::DB.read("schema")
        expect(schema["styleSheet"]).to eq(stylesheet)
      end
    end

    describe "POST /v1/Assistants/:assistant_sid/Defaults" do
      it "returns 200" do
        assistant_sid = "AC123"
        defaults = {
          "some" => {
            "fake" => [{ "default" => "attrs" }],
          },
        }
        params = {
          Defaults: defaults.to_json,
        }
        TwilioStub::DB.write("schema", TwilioStub::DEFAULT_SCHEMA)

        post "/v1/Assistants/#{assistant_sid}/Defaults", params

        expect(last_response.status).to eq(200)
      end

      it "returns empty hash" do
        assistant_sid = "AC123"
        defaults = {
          "some" => {
            "fake" => [{ "default" => "attrs" }],
          },
        }
        params = {
          Defaults: defaults.to_json,
        }
        TwilioStub::DB.write("schema", TwilioStub::DEFAULT_SCHEMA)

        post "/v1/Assistants/#{assistant_sid}/Defaults", params

        parsed = JSON.parse(last_response.body)
        expect(parsed).to eq({})
      end

      it "writes defaults to db" do
        assistant_sid = "AC123"
        defaults = {
          "some" => {
            "fake" => [{ "default" => "attrs" }],
          },
        }
        params = {
          Defaults: defaults.to_json,
        }
        TwilioStub::DB.write("schema", TwilioStub::DEFAULT_SCHEMA)

        post "/v1/Assistants/#{assistant_sid}/Defaults", params

        schema = TwilioStub::DB.read("schema")
        expect(schema["defaults"]).to eq(defaults)
      end
    end

    describe "POST /v1/Assistants/:assistant_sid/Tasks" do
      it "returns 200" do
        assistant_sid = "AC123"
        actions = {
          "some" => {
            "fake" => [{ "action" => "name" }],
          },
        }
        uniq_name = "fake_name"
        params = {
          UniqueName: uniq_name,
          Actions: actions.to_json,
        }
        TwilioStub::DB.write("schema", TwilioStub::DEFAULT_SCHEMA)

        post "/v1/Assistants/#{assistant_sid}/Tasks", params

        expect(last_response.status).to eq(200)
      end

      it "returns sid" do
        assistant_sid = "AC123"
        md5 = "fake_md5"
        sid = "UD#{md5}"
        actions = {
          "some" => {
            "fake" => [{ "action" => "name" }],
          },
        }
        uniq_name = "fake_name"
        params = {
          UniqueName: uniq_name,
          Actions: actions.to_json,
        }
        allow(Faker::Crypto).to receive(:md5).and_return(md5)
        TwilioStub::DB.write("schema", TwilioStub::DEFAULT_SCHEMA)

        post "/v1/Assistants/#{assistant_sid}/Tasks", params

        parsed = JSON.parse(last_response.body)
        expect(parsed).to eq({ "sid" => sid })
      end

      it "writes defaults to db" do
        assistant_sid = "AC123"
        md5 = "fake_md5"
        sid = "UD#{md5}"
        actions = {
          "some" => {
            "fake" => [{ "action" => "name" }],
          },
        }
        uniq_name = "fake_name"
        expected_tasks = [{
          "sid" => sid,
          "uniqueName" => uniq_name,
          "fields" => [],
          "actions" => actions,
          "samples" => [],
        }]
        params = {
          UniqueName: uniq_name,
          Actions: actions.to_json,
        }
        allow(Faker::Crypto).to receive(:md5).and_return(md5)
        TwilioStub::DB.write("schema", TwilioStub::DEFAULT_SCHEMA)

        post "/v1/Assistants/#{assistant_sid}/Tasks", params

        schema = TwilioStub::DB.read("schema")
        expect(schema["tasks"]).to eq(expected_tasks)
      end

      context "when schema already have tasks" do
        it "adds new task" do
          assistant_sid = "AC123"
          md5 = "fake_md5"
          sid = "UD#{md5}"
          actions = {
            "some" => {
              "fake" => [{ "action" => "name" }],
            },
          }
          uniq_name = "fake_name"
          existing_task = {
            "sid" => "fake_sid",
            "uniqueName" => "fake_uniq_name",
            "fields" => [],
            "actions" => { "fake" => "action" },
            "samples" => [],
          }
          expected_tasks = [existing_task, {
            "sid" => sid,
            "uniqueName" => uniq_name,
            "fields" => [],
            "actions" => actions,
            "samples" => [],
          }]
          params = {
            UniqueName: uniq_name,
            Actions: actions.to_json,
          }
          allow(Faker::Crypto).to receive(:md5).and_return(md5)
          current_schema = TwilioStub::DEFAULT_SCHEMA.dup
          current_schema["tasks"] = [existing_task]
          TwilioStub::DB.write("schema", current_schema)

          post "/v1/Assistants/#{assistant_sid}/Tasks", params

          schema = TwilioStub::DB.read("schema")
          expect(schema["tasks"]).to eq(expected_tasks)
        end
      end
    end

    describe "DELETE /v1/Assistants/:assistant_sid/Tasks/:task_id" do
      it "returns 200" do
        assistant_sid = "AC123"
        task_sid = "UD123"
        task = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
          "sid" => task_sid,
          "samples" => [],
        )
        schema = TwilioStub::DEFAULT_SCHEMA.merge(
          "tasks" => [task],
        )
        TwilioStub::DB.write("schema", schema)
        url = [
          "v1",
          "Assistants",
          assistant_sid,
          "Tasks",
          task_sid,
        ].join("/")

        delete "/#{url}"

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq({})
      end

      it "deletes sample from array" do
        assistant_sid = "AC123"
        task_sid = "UD123"
        other_task = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
          "sid" => "other_task_sid",
        )
        task = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
          "sid" => task_sid,
        )
        schema = TwilioStub::DEFAULT_SCHEMA.merge(
          "tasks" => [task, other_task],
        )
        TwilioStub::DB.write("schema", schema)
        url = [
          "v1",
          "Assistants",
          assistant_sid,
          "Tasks",
          task_sid,
        ].join("/")

        delete "/#{url}"

        schema = TwilioStub::DB.read("schema")
        expect(schema["tasks"]).to eq([other_task])
      end
    end

    describe "POST /v1/Assistants/:assistant_sid/Tasks/:task_id/Samples" do
      it "returns 200" do
        assistant_sid = "AC123"
        task_sid = "UD123"
        task = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
          "sid" => task_sid,
        )
        schema = TwilioStub::DEFAULT_SCHEMA.merge(
          "tasks" => [task],
        )
        TwilioStub::DB.write("schema", schema)
        params = {
          Language: "en-US",
          TaggedText: "fake tagged text",
        }
        url = [
          "v1",
          "Assistants",
          assistant_sid,
          "Tasks",
          task_sid,
          "Samples",
        ].join("/")

        post "/#{url}", params

        expect(last_response.status).to eq(200)
      end

      it "returns sid" do
        assistant_sid = "AC123"
        task_sid = "UD123"
        md5 = "fake_md5"
        sample_sid = "UF#{md5}"
        task = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
          "sid" => task_sid,
        )
        schema = TwilioStub::DEFAULT_SCHEMA.merge(
          "tasks" => [task],
        )
        TwilioStub::DB.write("schema", schema)
        params = {
          Language: "en-US",
          TaggedText: "fake tagged text",
        }
        allow(Faker::Crypto).to receive(:md5).and_return(md5)
        url = [
          "v1",
          "Assistants",
          assistant_sid,
          "Tasks",
          task_sid,
          "Samples",
        ].join("/")

        post "/#{url}", params

        parsed = JSON.parse(last_response.body)
        expect(parsed).to eq({ "sid" => sample_sid })
      end

      it "writes sample to db" do
        assistant_sid = "AC123"
        task_sid = "UD123"
        md5 = "fake_md5"
        sample_sid = "UF#{md5}"
        task = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
          "sid" => task_sid,
        )
        schema = TwilioStub::DEFAULT_SCHEMA.merge(
          "tasks" => [task],
        )
        TwilioStub::DB.write("schema", schema)
        params = {
          Language: "en-US",
          TaggedText: "fake tagged text",
        }
        expected_samples = [
          {
            "sid" => sample_sid,
            "Language" => "en-US",
            "TaggedText" => "fake tagged text",
          },
        ]
        allow(Faker::Crypto).to receive(:md5).and_return(md5)
        url = [
          "v1",
          "Assistants",
          assistant_sid,
          "Tasks",
          task_sid,
          "Samples",
        ].join("/")

        post "/#{url}", params

        schema = TwilioStub::DB.read("schema")
        task = schema["tasks"].detect { |t| t["sid"] == task_sid }
        expect(task["samples"]).to eq(expected_samples)
      end

      context "when schema already have tasks" do
        it "adds new task" do
          assistant_sid = "AC123"
          task_sid = "UD123"
          md5 = "fake_md5"
          sample_sid = "UF#{md5}"
          sample = {
            "sid" => "fake_first_sid",
            "Language" => "fake lang",
            "TaggedText" => "fake lang",
          }
          task1 = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
            "sid" => "fake task sid",
            "samples" => [sample],
          )
          task2 = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
            "sid" => task_sid,
            "samples" => [sample],
          )
          task3 = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
            "sid" => "fake task sid 2",
            "samples" => [sample],
          )
          schema = TwilioStub::DEFAULT_SCHEMA.merge(
            "tasks" => [
              task1,
              task2,
              task3,
            ],
          )
          TwilioStub::DB.write("schema", schema)
          params = {
            Language: "en-US",
            TaggedText: "fake tagged text",
          }
          expected_task = task2.merge(
            "samples" => [
              sample,
              {
                "sid" => sample_sid,
                "Language" => "en-US",
                "TaggedText" => "fake tagged text",
              },
            ],
          )
          expected_tasks = [
            task1,
            expected_task,
            task3,
          ]
          allow(Faker::Crypto).to receive(:md5).and_return(md5)
          url = [
            "v1",
            "Assistants",
            assistant_sid,
            "Tasks",
            task_sid,
            "Samples",
          ].join("/")

          post "/#{url}", params

          schema = TwilioStub::DB.read("schema")
          expect(schema["tasks"]).to eq(expected_tasks)
        end
      end
    end

    describe(
      "DELETE /v1/Assistants/:assistant_sid/Tasks/:task_id/Samples/:sample_sid",
    ) do
      it "returns 200" do
        assistant_sid = "AC123"
        task_sid = "UD123"
        sample_sid = "UF123"
        task = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
          "sid" => task_sid,
          "samples" => [{
            "sid" => sample_sid,
            "some" => "fake",
          }],
        )
        schema = TwilioStub::DEFAULT_SCHEMA.merge(
          "tasks" => [task],
        )
        TwilioStub::DB.write("schema", schema)
        url = [
          "v1",
          "Assistants",
          assistant_sid,
          "Tasks",
          task_sid,
          "Samples",
          sample_sid,
        ].join("/")

        delete "/#{url}"

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq({})
      end

      it "deletes sample from array" do
        assistant_sid = "AC123"
        task_sid = "UD123"
        sample_sid = "UF123"
        other_sample = {
          "sid" => "UF3456",
          "fake" => "data",
        }
        task = TwilioStub::DEFAULT_TASK_SCHEMA.merge(
          "sid" => task_sid,
          "samples" => [{
            "sid" => sample_sid,
            "some" => "fake",
          }, other_sample],
        )
        schema = TwilioStub::DEFAULT_SCHEMA.merge(
          "tasks" => [task],
        )
        TwilioStub::DB.write("schema", schema)
        url = [
          "v1",
          "Assistants",
          assistant_sid,
          "Tasks",
          task_sid,
          "Samples",
          sample_sid,
        ].join("/")

        delete "/#{url}"

        schema = TwilioStub::DB.read("schema")
        task = schema["tasks"].first
        expect(task["samples"]).to eq([other_sample])
      end
    end

    describe "POST /v1/Assistants/:assistant_sid/ModelBuilds" do
      it "returns 200" do
        sid = "fake_assistant_sid"

        post "/v1/Assistants/#{sid}/ModelBuilds"

        expect(last_response.status).to eq(200)
      end

      it "returns empty json" do
        sid = "fake_assistant_sid"

        post "/v1/Assistants/#{sid}/ModelBuilds"

        parsed = JSON.parse(last_response.body)
        expect(parsed).to eq({})
      end
    end

    describe "POST /:api_v/Accounts/:account_id/IncomingPhoneNumbers.json" do
      it "returns status 200" do
        post "/v2/Accounts/123/IncomingPhoneNumbers.json"

        expect(last_response.status).to eq(200)
      end

      it "writes phone number data to db" do
        md5 = "123"
        phone_number = "+4567"
        phone_number_sid = "PN#{md5}"

        allow(Faker::Crypto).to receive(:md5).and_return(md5)
        allow(Faker::PhoneNumber).
          to receive(:cell_phone_in_e164).
          and_return(phone_number)

        post "/v2/Accounts/123/IncomingPhoneNumbers.json"

        numbers = TwilioStub::DB.read("phone_numbers")

        expect(numbers).to be_an(Array)
        expect(numbers.count).to eq(1)
        number = numbers.first
        expect(number[:phone_number]).to eq(phone_number)
        expect(number[:phone_number_sid]).to eq(phone_number_sid)
      end

      it "returns phone number" do
        md5 = "123"
        phone_number = "+4567"
        phone_number_sid = "PN#{md5}"

        allow(Faker::Crypto).to receive(:md5).and_return(md5)
        allow(Faker::PhoneNumber).
          to receive(:cell_phone_in_e164).
          and_return(phone_number)

        post "/v2/Accounts/123/IncomingPhoneNumbers.json"

        response = JSON.parse(last_response.body)

        expect(response["phone_number"]).to eq(phone_number)
        expect(response["sid"]).to eq(phone_number_sid)
      end
    end

    describe "POST /:api_version/Accounts.json" do
      it "returns message sid" do
        name = "fake_friendly_name"
        sid = "fake_message_sid"
        full_sid = "AC#{sid}"
        params = {
          FriendlyName: name,
        }
        allow(Faker::Crypto).to receive(:md5).and_return(sid)

        post "/v2/Accounts.json", params

        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response["sid"]).to eq(full_sid)
      end
    end

    describe "GET /:api_version/Accounts/:assistant_sid/Messages/:message_sid.json" do # rubocop:disable Layout/LineLength
      it "returns sms_message" do
        message = {
          sid: "fake_sms_sid",
          body: "fake_body",
          ms_sid: "fake_sid",
          from: "fake_from",
          status: "delivered",
          num_media: "0",
          num_segments: "1",
          other: "other",
        }
        messages = [
          { sid: "other_sid" },
          message,
          { sid: "other_sid2" },
        ]
        expected_message = message.slice(:sid, :status, :num_media,
                                         :num_segments).transform_keys(&:to_s)
        TwilioStub::DB.write("sms_messages", messages)

        get "/2010-10-23/Accounts/fake_assistant_sid/Messages/#{message[:sid]}.json" # rubocop:disable Layout/LineLength

        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response).to eq(expected_message)
      end
    end

    describe "POST /:api_version/Accounts/:assistant_sid/Messages.json" do
      it "returns message sid" do
        assistant_sid = "fake_assistant_sid"
        body = "fake_body"
        message_service_sid = "fake_message_service_sid"
        to = "fake_to"
        sid = "fake_message_sid"
        full_sid = "MS#{sid}"
        params = {
          Body: body,
          MessagingServiceSid: message_service_sid,
          To: to,
        }
        allow(Faker::Crypto).to receive(:md5).and_return(sid)

        post "/v2/Accounts/#{assistant_sid}/Messages.json", params

        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response["sid"]).to eq(full_sid)
      end

      it "saves sms message" do
        assistant_sid = "fake_assistant_sid"
        body = "fake_body"
        message_service_sid = "fake_message_service_sid"
        to = "fake_to"
        sid = "fake_message_sid"
        full_sid = "MS#{sid}"
        params = {
          Body: body,
          MessagingServiceSid: message_service_sid,
          To: to,
        }
        allow(Faker::Crypto).to receive(:md5).and_return(sid)

        post "/v2/Accounts/#{assistant_sid}/Messages.json", params

        message = TwilioStub::DB.read("sms_messages").first
        expect(message[:sid]).to eq(full_sid)
        expect(message[:body]).to eq(body)
        expect(message[:ms_sid]).to eq(message_service_sid)
        expect(message[:to]).to eq(to)
        expect(message[:assistant_sid]).to eq(assistant_sid)
      end

      it "saves more than one message" do
        assistant_sid = "fake_assistant_sid"
        body1 = "fake_body"
        message_service_sid1 = "fake_message_service_sid"
        to1 = "fake_to"
        sid1 = "fake_message_sid"
        full_sid1 = "MS#{sid1}"
        body2 = "fake_body_2"
        message_service_sid2 = "fake_message_service_sid_2"
        to2 = "fake_to_2"
        sid2 = "fake_message_sid_2"
        full_sid2 = "MS#{sid2}"
        params1 = {
          Body: body1,
          MessagingServiceSid: message_service_sid1,
          To: to1,
        }
        params2 = {
          Body: body2,
          MessagingServiceSid: message_service_sid2,
          To: to2,
        }
        allow(Faker::Crypto).to receive(:md5).and_return(sid1, sid2)

        post "/v2/Accounts/#{assistant_sid}/Messages.json", params1
        post "/v2/Accounts/#{assistant_sid}/Messages.json", params2

        messages = TwilioStub::DB.read("sms_messages")
        expect(messages.count).to eq(2)
        expect(messages.first).to eq(
          sid: full_sid1,
          body: body1,
          ms_sid: message_service_sid1,
          to: to1,
          assistant_sid: assistant_sid,
          status: "delivered",
          num_media: "0",
          num_segments: "1",
        )
        expect(messages.last).to eq(
          sid: full_sid2,
          body: body2,
          ms_sid: message_service_sid2,
          to: to2,
          assistant_sid: assistant_sid,
          status: "delivered",
          num_media: "0",
          num_segments: "1",
        )
      end
    end
  end

  def stub_dialog_resolver
    dialog_resolver = instance_double(TwilioStub::DialogResolver)
    allow(TwilioStub::DialogResolver).
      to receive(:new).
      and_return(dialog_resolver)
    allow(dialog_resolver).to receive(:call)
    dialog_resolver
  end
end
