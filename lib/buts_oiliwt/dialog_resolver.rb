require "net/http"
require "uri"

require "buts_oiliwt/db"

module ButsOiliwt
  class DialogResolver
    def initialize(channel_name, async_task)
      @channel_name = channel_name
      @async_task = async_task
    end

    def call
      if DB.read("channel_#{@channel_name}_collection")
        resolve_next_message
      else
        resolve_first_message
      end
    end

    private

    def resolve_first_message
      task = find_task_by_name("greeting")
      redirect = task.dig("actions", "actions", 0, "redirect")
      task_name = redirect.gsub("task://", "")

      next_task = find_task_by_name(task_name)
      DB.write(
        "channel_#{@channel_name}_dialog_sid",
        random_dialog_string,
      )
      handle_task_start(next_task.dig("actions", "actions"))
    end

    def handle_task_start(actions)
      actions.each do |action|
        if action.key?("say")
          write_message(action["say"])
        elsif action.key?("collect")
          DB.write(
            "channel_#{@channel_name}_results",
            {},
          )
          DB.write(
           "channel_#{@channel_name}_collection",
            action,
          )
          write_message(
            action.dig(
              "collect",
              "questions",
              0,
              "question",
            ),
          )
        elsif action.key?("redirect")
          dialog_sid = DB.read("channel_#{@channel_name}_dialog_sid")
          url = action.dig("redirect", "uri")
          body = {
            DialogueSid: dialog_sid,
          }

          result = Net::HTTP.post_form(
            URI(url),
            body,
          )

          actions = JSON.parse(result.body)["actions"]

          handle_task_start(actions)
        end
      end
    end

    def resolve_next_message
      collection = DB.read("channel_#{@channel_name}_collection")
      results = DB.read("channel_#{@channel_name}_results")
      messages_key = "channel_#{@channel_name}_messages"
      messages = DB.read(messages_key)

      current_name = collection.dig(
        "collect",
        "questions",
        results.keys.count,
        "name",
      )
      results[current_name] = messages.last[:body]

      next_question = collection.dig(
        "collect",
        "questions",
        results.keys.count,
        "question",
      )

      if next_question
        write_message(
          collection.dig(
            "collect",
            "questions",
            results.keys.count,
            "question",
          ),
        )
        DB.write("channel_#{@channel_name}_results", results)
      else
        resolve_on_complete_callback(results)
      end
    end

    def resolve_on_complete_callback(results)
      dialog_sid = DB.read("channel_#{@channel_name}_dialog_sid")
      body_results = results.map do |k, v|
        [k, { answer: v }]
      end.to_h

      body = {
        DialogueSid: dialog_sid,
        Memory: {
          twilio: {
            collected_data: {
              data_collect: {
                answers: body_results,
              },
            },
          },
        }.to_json,
      }

      url = DB.read("channel_#{@channel_name}_collection").dig(
        "collect",
        "on_complete",
        "redirect",
        "uri",
      )
      result = Net::HTTP.post_form(
        URI(url),
        body,
      )

      result_body = JSON.parse(result.body)
      action = result_body.dig("actions", 0)

      if action.key?("say")
        end_conversation(result_body)
      elsif action.key?("redirect")
        next_task = find_task_by_name(
          action["redirect"].gsub("task://", ""),
        )
        handle_task_start(
          next_task.dig("actions", "actions"),
        )

        if next_task["uniqueName"] == "complete"
          end_conversation
        end
      end
    end

    def end_conversation
      DB.write(
        "channel_#{@channel_name}_results",
        nil,
      )
      DB.write(
        "channel_#{@channel_name}_collection",
        nil,
      )

      @schema = nil
    end

    def find_task_by_name(name)
      schema.dig("tasks").detect do |task|
        task.dig("uniqueName") == name
      end
    end

    def write_message(message)
      messages_key = "channel_#{@channel_name}_messages"
      messages = DB.read(messages_key)
      messages.push(
        body: message,
        author: "bot",
        sid: random_message_string,
      )

      DB.write(messages_key, messages)
      @async_task.sleep(0.5)
    end

    def schema
      @schema ||= DB.read("schema")
    end

    def random_dialog_string
      (0...12).map { ("a".."z").to_a[rand(26)] }.join
    end

    def random_message_string
      (0...8).map { ("a".."z").to_a[rand(26)] }.join
    end
  end
end
