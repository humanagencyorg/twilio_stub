require "pry"
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
      db_messages = TwilioStub::DB.read(messages_key)
      db_messages.push(
        body: "Fake name",
        author: customer_id,
        sid: SecureRandom.hex,
      )
      TwilioStub::DB.write(
        messages_key,
        db_messages,
      )
      described_class.new(channel_name, task).call
      db_messages = TwilioStub::DB.read(messages_key)
      db_messages.push(
        body: "Fake second name",
        author: customer_id,
        sid: SecureRandom.hex,
      )
      TwilioStub::DB.write(
        messages_key,
        db_messages,
      )
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
      db_messages = TwilioStub::DB.read(messages_key)
      db_messages.push(
        body: "Fake name",
        author: customer_id,
        sid: SecureRandom.hex,
      )
      TwilioStub::DB.write(
        messages_key,
        db_messages,
      )
      described_class.new(channel_name, task).call
      db_messages = TwilioStub::DB.read(messages_key)
      db_messages.push(
        body: "Fake second name",
        author: customer_id,
        sid: SecureRandom.hex,
      )
      TwilioStub::DB.write(
        messages_key,
        db_messages,
      )
      described_class.new(channel_name, task).call
      db_messages = TwilioStub::DB.read(messages_key)
      db_messages.push(
        body: "email@fake.com",
        author: customer_id,
        sid: SecureRandom.hex,
      )
      TwilioStub::DB.write(
        messages_key,
        db_messages,
      )
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
      db_messages = TwilioStub::DB.read(messages_key)
      db_messages.push(
        body: "carbonara",
        author: customer_id,
        sid: SecureRandom.hex,
      )
      TwilioStub::DB.write(
        messages_key,
        db_messages,
      )
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
        db_messages = TwilioStub::DB.read(messages_key)
        db_messages.push(
          body: "banana",
          author: customer_id,
          sid: SecureRandom.hex,
        )
        TwilioStub::DB.write(
          messages_key,
          db_messages,
        )
        described_class.new(channel_name, task).call
        db_messages = TwilioStub::DB.read(messages_key)
        db_messages.push(
          body: "carbonara",
          author: customer_id,
          sid: SecureRandom.hex,
        )
        TwilioStub::DB.write(
          messages_key,
          db_messages,
        )
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
end
