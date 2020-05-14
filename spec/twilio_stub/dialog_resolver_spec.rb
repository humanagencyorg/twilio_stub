require "spec_helper"

RSpec.describe TwilioStub::DialogResolver do
  context "when conversation is not started yet" do
    it "looking for greeting action and execute it" do
      # Preparation
      task = fake_task_stub.new
      channel_name = "fake"
      messages_key = "channel_fake_messages"
      schema = {
        "tasks" => [
          {
            "uniqueName" => "greeting",
            "actions" => {
              "actions" => [
                { "say" => "hello" },
              ],
            },
          },
        ],
      }

      TwilioStub::DB.write("schema", schema)
      TwilioStub::DB.write(messages_key, [])

      # Execution
      described_class.new(channel_name, task).call

      # Expectation
      messages = TwilioStub::DB.read(messages_key)
      expect(messages.count).to eq(1)
      expect(messages.first[:body]).to eq("hello")
      expect(messages.first[:author]).to eq("bot")
      expect(messages.first[:sid].length).to eq(8)

      # Clean up
      TwilioStub::DB.clear_all
    end

    it "writes dialog_sid and task to db" do
      # Preparation
      task = fake_task_stub.new
      channel_name = "fake"
      messages_key = "channel_fake_messages"
      schema_task = {
        "uniqueName" => "greeting",
        "actions" => {
          "actions" => [
            { "say" => "hello" },
          ],
        },
      }
      schema = {
        "tasks" => [
          schema_task,
        ],
      }

      TwilioStub::DB.write("schema", schema)
      TwilioStub::DB.write(messages_key, [])

      # Execution
      described_class.new(channel_name, task).call

      # Expectation
      db_dialog_sid = TwilioStub::DB.read("channel_fake_dialog_sid")
      db_task = TwilioStub::DB.read("channel_fake_task")
      expect(db_dialog_sid.length).to eq(12)
      expect(db_task).to eq(schema_task)

      TwilioStub::DB.clear_all
    end

    context "when greeting contains redirect" do
      it "handles redirection" do
        # Preparation
        task = fake_task_stub.new
        channel_name = "fake"
        messages_key = "channel_fake_messages"
        block_task = {
          "uniqueName" => "block",
          "actions" => {
            "actions" => [
              { "say" => "block message" },
            ],
          },
        }
        schema = {
          "tasks" => [
            {
              "uniqueName" => "greeting",
              "actions" => {
                "actions" => [
                  { "say" => "hello" },
                  { "redirect" => "task://block" },
                ],
              },
            },
            block_task,
          ],
        }

        TwilioStub::DB.write("schema", schema)
        TwilioStub::DB.write(messages_key, [])

        # Execution
        described_class.new(channel_name, task).call

        # Expectation
        db_task = TwilioStub::DB.read("channel_fake_task")
        messages = TwilioStub::DB.read(messages_key)
        expect(messages.count).to eq(2)

        expect(messages[0][:body]).to eq("hello")
        expect(messages[0][:author]).to eq("bot")
        expect(messages[0][:sid].length).to eq(8)

        expect(messages[1][:body]).to eq("block message")
        expect(messages[1][:author]).to eq("bot")
        expect(messages[1][:sid].length).to eq(8)

        expect(db_task).to eq(block_task)

        # Clean up
        TwilioStub::DB.clear_all
      end
    end
  end

  context "when collection block" do
    it "starts collection block" do
      # Preparation
      task = fake_task_stub.new
      channel_name = "fake"
      messages_key = "channel_fake_messages"
      collect_action = {
        "collect" => {
          "questions" => [
            "question" => "How are you?",
          ],
        },
      }
      collect_task = {
        "uniqueName" => "block",
        "actions" => {
          "actions" => [
            collect_action,
          ],
        },
      }
      schema = {
        "tasks" => [
          {
            "uniqueName" => "greeting",
            "actions" => {
              "actions" => [
                { "redirect" => "task://block" },
              ],
            },
          },
          collect_task,
        ],
      }

      TwilioStub::DB.write("schema", schema)
      TwilioStub::DB.write(messages_key, [])

      # Execution
      described_class.new(channel_name, task).call

      # Expectation
      db_task = TwilioStub::DB.read("channel_fake_task")
      db_results = TwilioStub::DB.read("channel_fake_results")
      db_action = TwilioStub::DB.read("channel_fake_action")
      messages = TwilioStub::DB.read(messages_key)
      expect(messages.count).to eq(1)

      expect(messages[0][:body]).to eq("How are you?")
      expect(messages[0][:author]).to eq("bot")
      expect(messages[0][:sid].length).to eq(8)

      expect(db_task).to eq(collect_task)
      expect(db_action).to eq(collect_action)
      expect(db_results).to eq({})

      expect(task.sleeps.count).to eq(1)
      expect(task.sleeps).to eq([0.5])

      # Clean up
      TwilioStub::DB.clear_all
    end

    it "collects results" do
      customer_id = "fake_custom_id"
      task = fake_task_stub.new
      channel_name = "fake"
      messages_key = "channel_fake_messages"
      write_message = message_writer(
        key: messages_key,
        author: customer_id,
      )
      expected_results = {
        "name" => "Fake name",
        "second_name" => "Fake second name",
      }
      expected_messages = [
        "What is your name?",
        "Fake name",
        "What is your second name?",
        "Fake second name",
        "What is your email?",
      ]
      schema = {
        "tasks" => [
          {
            "uniqueName" => "greeting",
            "actions" => {
              "actions" => [
                { "redirect" => "task://block" },
              ],
            },
          },
          "uniqueName" => "block",
          "actions" => {
            "actions" => [
              "collect" => {
                "questions" => [
                  {
                    "question" => "What is your name?",
                    "name" => "name",
                  },
                  {
                    "question" => "What is your second name?",
                    "name" => "second_name",
                  },
                  {
                    "question" => "What is your email?",
                    "name" => "email",
                  },
                ],
              },
            ],
          },
        ],
      }

      TwilioStub::DB.write("schema", schema)
      TwilioStub::DB.write(messages_key, [])

      # Execution
      described_class.new(channel_name, task).call
      write_message.("Fake name")
      described_class.new(channel_name, task).call
      write_message.("Fake second name")
      described_class.new(channel_name, task).call

      # Expectation
      db_results = TwilioStub::DB.read("channel_fake_results")
      db_messages = TwilioStub::DB.read(messages_key)

      expect(db_results).to eq(expected_results)

      expect(db_messages.count).to eq(5)
      messages = db_messages.map { |d| d[:body] }
      expect(messages).to eq(expected_messages)

      # Clean up
      TwilioStub::DB.clear_all
    end

    it "sends results and react to webhook" do
      customer_id = "fake_custom_id"
      task = fake_task_stub.new
      channel_name = "fake"
      messages_key = "channel_fake_messages"
      write_message = message_writer(
        key: messages_key,
        author: customer_id,
      )
      expected_messages = [
        "What is your name?",
        "Fake name",
        "What is your second name?",
        "Fake second name",
        "What is your email?",
        "email@fake.com",
        "thank you",
      ]
      schema = {
        "tasks" => [
          {
            "uniqueName" => "greeting",
            "actions" => {
              "actions" => [
                { "redirect" => "task://block" },
              ],
            },
          },
          "uniqueName" => "block",
          "actions" => {
            "actions" => [
              "collect" => {
                "questions" => [
                  {
                    "question" => "What is your name?",
                    "name" => "name",
                  },
                  {
                    "question" => "What is your second name?",
                    "name" => "second_name",
                  },
                  {
                    "question" => "What is your email?",
                    "name" => "email",
                  },
                ],
                "on_complete" => {
                  "redirect" => {
                    "uri" => "http://fakeurl.com",
                  },
                },
              },
            ],
          },
        ],
      }
      stub_request(:post, "http://fakeurl.com/").
        with(
          body: {
            "DialogueSid" => /.*/,
            "Memory" => {
              "twilio" => {
                "collected_data" => {
                  "data_collect" => {
                    "answers" => {
                      "name" => { "answer" => "Fake name" },
                      "second_name" => { "answer" => "Fake second name" },
                      "email" => { "answer" => "email@fake.com" },
                    },
                  },
                },
              },
            }.to_json,
          },
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Content-Type" => "application/x-www-form-urlencoded",
            "Host" => "fakeurl.com",
            "User-Agent" => "Ruby",
          },
        ).
        to_return(
          status: 200,
          body: { "actions" => [{ "say" => "thank you" }] }.to_json,
          headers: {},
        )

      TwilioStub::DB.write("schema", schema)
      TwilioStub::DB.write(messages_key, [])

      # Execution
      described_class.new(channel_name, task).call
      write_message.("Fake name")
      described_class.new(channel_name, task).call
      write_message.("Fake second name")
      described_class.new(channel_name, task).call
      write_message.("email@fake.com")
      described_class.new(channel_name, task).call

      # Expectation
      db_results = TwilioStub::DB.read("channel_fake_results")
      db_action = TwilioStub::DB.read("channel_fake_action")
      db_task = TwilioStub::DB.read("channel_fake_task")
      db_messages = TwilioStub::DB.read(messages_key)

      expect(db_results).to be_nil
      expect(db_action).to be_nil
      expect(db_task).to be_nil

      expect(db_messages.count).to eq(7)
      messages = db_messages.map { |d| d[:body] }
      expect(messages).to eq(expected_messages)

      expect(task.sleeps).to eq(Array.new(4, 0.5))

      # Clean up
      TwilioStub::DB.clear_all
    end

    context "when collect question contains validation" do
      context "whan contain allowed_values" do
        it "validates result by allowed_values list" do
          TwilioStub::DB.clear_all

          customer_id = "fake_custom_id"
          task = fake_task_stub.new
          channel_name = "fake"
          messages_key = "channel_fake_messages"
          expected_messages = [
            "Are you sure?",
            "no",
            "It should be yes",
            "no",
            "Say yes, plz",
            "yes",
            "Thanks",
            "What is your name?",
            "First name",
            "thank you",
          ]
          write_message = message_writer(
            key: messages_key,
            author: customer_id,
          )
          schema = {
            "styleSheet" => {
              "style_sheet" => {
                "collect" => {
                  "validate" => {
                    "on_failure" => {
                      "repeat_question" => false,
                    },
                  },
                },
              },
            },
            "tasks" => [
              {
                "uniqueName" => "greeting",
                "actions" => {
                  "actions" => [
                    { "redirect" => "task://block" },
                  ],
                },
              },
              "uniqueName" => "block",
              "actions" => {
                "actions" => [
                  "collect" => {
                    "questions" => [
                      {
                        "question" => "Are you sure?",
                        "name" => "term",
                        "validate" => {
                          "allowed_values" => {
                            "list" => ["yes"],
                          },
                          "on_failure" => {
                            "messages" => [
                              { "say" => "It should be yes" },
                              { "say" => "Say yes, plz" },
                            ],
                          },
                          "on_success" => {
                            "say" => "Thanks",
                          },
                        },
                      },
                      {
                        "question" => "What is your name?",
                        "name" => "name",
                      },
                    ],
                    "on_complete" => {
                      "redirect" => {
                        "uri" => "http://fakeurl.com",
                      },
                    },
                  },
                ],
              },
            ],
          }
          stub_request(:post, "http://fakeurl.com/").
            with(
              body: {
                "DialogueSid" => /.*/,
                "Memory" => {
                  "twilio" => {
                    "collected_data" => {
                      "data_collect" => {
                        "answers" => {
                          "term" => { "answer" => "yes" },
                          "name" => { "answer" => "First name" },
                        },
                      },
                    },
                  },
                }.to_json,
              },
              headers: {
                "Accept" => "*/*",
                "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
                "Content-Type" => "application/x-www-form-urlencoded",
                "Host" => "fakeurl.com",
                "User-Agent" => "Ruby",
              },
            ).
            to_return(
              status: 200,
              body: { "actions" => [{ "say" => "thank you" }] }.to_json,
              headers: {},
            )

          TwilioStub::DB.write("schema", schema)
          TwilioStub::DB.write(messages_key, [])

          # Execution
          described_class.new(channel_name, task).call
          write_message.("no")
          described_class.new(channel_name, task).call
          write_message.("no")
          described_class.new(channel_name, task).call
          write_message.("yes")
          described_class.new(channel_name, task).call
          write_message.("First name")
          described_class.new(channel_name, task).call

          # Expectation
          db_results = TwilioStub::DB.read("channel_fake_results")
          db_action = TwilioStub::DB.read("channel_fake_action")
          db_task = TwilioStub::DB.read("channel_fake_task")
          db_messages = TwilioStub::DB.read(messages_key)

          expect(db_results).to be_nil
          expect(db_action).to be_nil
          expect(db_task).to be_nil

          expect(db_messages.count).to eq(10)
          messages = db_messages.map { |d| d[:body] }
          expect(messages).to eq(expected_messages)

          expect(task.sleeps).to eq(Array.new(6, 0.5))

          # Clean up
          TwilioStub::DB.clear_all
        end
      end

      context "when validated by type" do
        it "validates by types" do
          TwilioStub::DB.clear_all
          customer_id = "fake_custom_id"
          task = fake_task_stub.new
          channel_name = "fake"
          messages_key = "channel_fake_messages"
          write_message = message_writer(
            key: messages_key,
            author: customer_id,
          )
          expected_messages = [
            "Are you sure?",
            "fake",
            "I didn't get.",
            "yes",
            "What is your name?",
            "fake first name",
            "I didn't get.",
            "Name",
            "What is your second name?",
            "fake second name",
            "I didn't get.",
            "Second",
            "What is your email?",
            "fake.com",
            "I didn't get.",
            "email@fake.com",
            "What is your city?",
            "Fake",
            "I didn't get.",
            "Kyiv",
            "What is your country?",
            "Fake",
            "I didn't get.",
            "Ukraine",
            "What is your us state?",
            "FAKE",
            "I didn't get.",
            "NY",
            "What is your zip code?",
            "871638461278364813",
            "I didn't get.",
            "123123",
            "What is your phone number?",
            "871638461278364813",
            "I didn't get.",
            "8716384612",
            "thanks",
          ]
          schema = {
            "styleSheet" => {
              "style_sheet" => {
                "collect" => {
                  "validate" => {
                    "on_failure" => {
                      "messages" => [
                        { "say" => "I didn't get." },
                      ],
                      "repeat_question" => false,
                    },
                  },
                },
              },
            },
            "tasks" => [
              {
                "uniqueName" => "greeting",
                "actions" => {
                  "actions" => [
                    { "redirect" => "task://block" },
                  ],
                },
              },
              "uniqueName" => "block",
              "actions" => {
                "actions" => [
                  "collect" => {
                    "questions" => [
                      {
                        "question" => "Are you sure?",
                        "name" => "term",
                        "type" => "Twilio.YES_NO",
                        "validate" => true,
                      },
                      {
                        "question" => "What is your name?",
                        "name" => "name",
                        "type" => "Twilio.FIRST_NAME",
                        "validate" => true,
                      },
                      {
                        "question" => "What is your second name?",
                        "name" => "second_name",
                        "type" => "Twilio.LAST_NAME",
                        "validate" => true,
                      },
                      {
                        "question" => "What is your email?",
                        "name" => "email",
                        "type" => "Twilio.EMAIL",
                        "validate" => true,
                      },
                      {
                        "question" => "What is your city?",
                        "name" => "city",
                        "type" => "Twilio.CITY",
                        "validate" => true,
                      },
                      {
                        "question" => "What is your country?",
                        "name" => "country",
                        "type" => "Twilio.COUNTRY",
                        "validate" => true,
                      },
                      {
                        "question" => "What is your us state?",
                        "name" => "state",
                        "type" => "Twilio.US_STATE",
                        "validate" => true,
                      },
                      {
                        "question" => "What is your zip code?",
                        "name" => "zip_code",
                        "type" => "Twilio.ZIP_CODE",
                        "validate" => true,
                      },
                      {
                        "question" => "What is your phone number?",
                        "name" => "phone_number",
                        "type" => "Twilio.PHONE_NUMBER",
                        "validate" => true,
                      },
                    ],
                    "on_complete" => {
                      "redirect" => {
                        "uri" => "http://fakeurl.com",
                      },
                    },
                  },
                ],
              },
            ],
          }
          stub_request(:post, "http://fakeurl.com/").
            with(
              body: {
                "DialogueSid" => /.*/,
                "Memory" => {
                  "twilio" => {
                    "collected_data" => {
                      "data_collect" => {
                        "answers" => {
                          "term" => { "answer" => "yes" },
                          "name" => { "answer" => "Name" },
                          "second_name" => { "answer" => "Second" },
                          "email" => { "answer" => "email@fake.com" },
                          "city" => { "answer" => "Kyiv" },
                          "country" => { "answer" => "Ukraine" },
                          "state" => { "answer" => "NY" },
                          "zip_code" => { "answer" => "123123" },
                          "phone_number" => { "answer" => "8716384612" },
                        },
                      },
                    },
                  },
                }.to_json,
              },
              headers: {
                "Accept" => "*/*",
                "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
                "Content-Type" => "application/x-www-form-urlencoded",
                "Host" => "fakeurl.com",
                "User-Agent" => "Ruby",
              },
            ).
            to_return(
              status: 200,
              body: { "actions" => [{ "say" => "thanks" }] }.to_json,
              headers: {},
            )
          TwilioStub::DB.write("schema", schema)
          TwilioStub::DB.write(messages_key, [])

          # Execution
          described_class.new(channel_name, task).call
          write_message.("fake")
          described_class.new(channel_name, task).call
          write_message.("yes")
          described_class.new(channel_name, task).call
          write_message.("fake first name")
          described_class.new(channel_name, task).call
          write_message.("Name")
          described_class.new(channel_name, task).call
          write_message.("fake second name")
          described_class.new(channel_name, task).call
          write_message.("Second")
          described_class.new(channel_name, task).call
          write_message.("fake.com")
          described_class.new(channel_name, task).call
          write_message.("email@fake.com")
          described_class.new(channel_name, task).call
          write_message.("Fake")
          described_class.new(channel_name, task).call
          write_message.("Kyiv")
          described_class.new(channel_name, task).call
          write_message.("Fake")
          described_class.new(channel_name, task).call
          write_message.("Ukraine")
          described_class.new(channel_name, task).call
          write_message.("FAKE")
          described_class.new(channel_name, task).call
          write_message.("NY")
          described_class.new(channel_name, task).call
          write_message.("871638461278364813")
          described_class.new(channel_name, task).call
          write_message.("123123")
          described_class.new(channel_name, task).call
          write_message.("871638461278364813")
          described_class.new(channel_name, task).call
          write_message.("8716384612")
          described_class.new(channel_name, task).call

          # Expectation
          db_results = TwilioStub::DB.read("channel_fake_results")
          db_action = TwilioStub::DB.read("channel_fake_action")
          db_task = TwilioStub::DB.read("channel_fake_task")
          db_messages = TwilioStub::DB.read(messages_key)

          expect(db_results).to be_nil
          expect(db_action).to be_nil
          expect(db_task).to be_nil

          expect(db_messages.count).to eq(37)
          messages = db_messages.map { |d| d[:body] }

          expect(messages).to eq(expected_messages)

          expect(task.sleeps).to eq(Array.new(19, 0.5))

          # Clean up
          TwilioStub::DB.clear_all
        end
      end
    end
  end

  context "when listening block" do
    it "listens for bunch of tasks and makes request when result found" do
      customer_id = "fake_custom_id"
      task = fake_task_stub.new
      channel_name = "fake"
      expected_messages = [
        "What pizza do you like?",
        "carbonara",
        "Thank you",
      ]
      messages_key = "channel_fake_messages"
      write_message = message_writer(
        key: messages_key,
        author: customer_id,
      )
      schema = {
        "tasks" => [
          {
            "uniqueName" => "greeting",
            "actions" => {
              "actions" => [
                { "redirect" => "task://block" },
              ],
            },
          },
          {
            "uniqueName" => "option_1",
            "actions" => {
              "actions" => [
                {
                  "redirect" => {
                    "uri" => "http://fake.com/el_diablo",
                  },
                },
              ],
            },
            "samples" => [
              { "taggedText" => "el_diablo" },
            ],
          },
          {
            "uniqueName" => "option_2",
            "actions" => {
              "actions" => [
                {
                  "redirect" => {
                    "uri" => "http://fake.com/carbonara",
                  },
                },
              ],
            },
            "samples" => [
              { "taggedText" => "carbonara" },
            ],
          },
          {
            "uniqueName" => "block",
            "actions" => {
              "actions" => [
                { "say" => "What pizza do you like?" },
                {
                  "listen" => {
                    "tasks" => [
                      "option_1",
                      "option_2",
                    ],
                  },
                },
              ],
            },
          },
        ],
      }

      stub_request(:post, "http://fake.com/carbonara").
        with(
          body: { "DialogueSid" => /.*/ },
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Content-Type" => "application/x-www-form-urlencoded",
            "Host" => "fake.com",
            "User-Agent" => "Ruby",
          },
        ).
        to_return(
          status: 200,
          body: { "actions" => ["say" => "Thank you"] }.to_json,
          headers: {},
        )

      TwilioStub::DB.write("schema", schema)
      TwilioStub::DB.write(messages_key, [])

      # Execution
      described_class.new(channel_name, task).call
      write_message.("carbonara")
      described_class.new(channel_name, task).call

      # Expectation
      db_results = TwilioStub::DB.read("channel_fake_results")
      db_action = TwilioStub::DB.read("channel_fake_action")
      db_task = TwilioStub::DB.read("channel_fake_task")
      db_messages = TwilioStub::DB.read(messages_key)

      expect(db_results).to be_nil
      expect(db_action).to be_nil
      expect(db_task).to be_nil

      expect(db_messages.count).to eq(3)
      messages = db_messages.map { |d| d[:body] }
      expect(messages).to eq(expected_messages)

      expect(task.sleeps).to eq(Array.new(2, 0.5))

      # Clean up
      TwilioStub::DB.clear_all
    end

    context "when option is not found" do
      it "starts task again" do
        customer_id = "fake_custom_id"
        task = fake_task_stub.new
        channel_name = "fake"
        expected_messages = [
          "What pizza do you like?",
          "banana",
          "What pizza do you like?",
          "carbonara",
          "Thank you",
        ]
        messages_key = "channel_fake_messages"
        write_message = message_writer(
          key: messages_key,
          author: customer_id,
        )
        schema = {
          "tasks" => [
            {
              "uniqueName" => "greeting",
              "actions" => {
                "actions" => [
                  { "redirect" => "task://block" },
                ],
              },
            },
            {
              "uniqueName" => "option_1",
              "actions" => {
                "actions" => [
                  {
                    "redirect" => {
                      "uri" => "http://fake.com/el_diablo",
                    },
                  },
                ],
              },
              "samples" => [
                { "taggedText" => "el_diablo" },
              ],
            },
            {
              "uniqueName" => "option_2",
              "actions" => {
                "actions" => [
                  {
                    "redirect" => {
                      "uri" => "http://fake.com/carbonara",
                    },
                  },
                ],
              },
              "samples" => [
                { "taggedText" => "carbonara" },
              ],
            },
            {
              "uniqueName" => "block",
              "actions" => {
                "actions" => [
                  { "say" => "What pizza do you like?" },
                  {
                    "listen" => {
                      "tasks" => [
                        "option_1",
                        "option_2",
                      ],
                    },
                  },
                ],
              },
            },
          ],
        }

        stub_request(:post, "http://fake.com/carbonara").
          with(
            body: { "DialogueSid" => /.*/ },
            headers: {
              "Accept" => "*/*",
              "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
              "Content-Type" => "application/x-www-form-urlencoded",
              "Host" => "fake.com",
              "User-Agent" => "Ruby",
            },
          ).
          to_return(
            status: 200,
            body: { "actions" => ["say" => "Thank you"] }.to_json,
            headers: {},
          )

        TwilioStub::DB.write("schema", schema)
        TwilioStub::DB.write(messages_key, [])

        # Execution
        described_class.new(channel_name, task).call
        write_message.("banana")
        described_class.new(channel_name, task).call
        write_message.("carbonara")
        described_class.new(channel_name, task).call

        # Expectation
        db_results = TwilioStub::DB.read("channel_fake_results")
        db_action = TwilioStub::DB.read("channel_fake_action")
        db_task = TwilioStub::DB.read("channel_fake_task")
        db_messages = TwilioStub::DB.read(messages_key)

        expect(db_results).to be_nil
        expect(db_action).to be_nil
        expect(db_task).to be_nil

        expect(db_messages.count).to eq(5)
        messages = db_messages.map { |d| d[:body] }
        expect(messages).to eq(expected_messages)

        expect(task.sleeps).to eq(Array.new(3, 0.5))

        # Clean up
        TwilioStub::DB.clear_all
      end
    end
  end

  def fake_task_stub
    Class.new do
      def sleep(amount)
        @sleeps ||= []
        @sleeps.push(amount)
      end

      def sleeps
        @sleeps
      end
    end
  end

  def message_writer(key:, author:)
    lambda do |body|
      db_messages = TwilioStub::DB.read(key)
      db_messages.push(
        body: body,
        author: author,
        sid: SecureRandom.hex,
      )
      TwilioStub::DB.write(
        key,
        db_messages,
      )
    end
  end
end
