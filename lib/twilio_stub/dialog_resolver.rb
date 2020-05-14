require "net/http"
require "uri"

require "twilio_stub/db"

module TwilioStub
  class DialogResolver
    def initialize(channel_name, async_task)
      @channel_name = channel_name
      @async_task = async_task
    end

    def call
      current_task = read_data("action")

      return start_dialog unless current_task

      case get_action_type(read_data("action"))
      when "collect"
        continue_collect_dialog
      when "listen"
        finish_listen_dialog
      end
    end

    private

    def read_data(postfix)
      DB.read("channel_#{@channel_name}_#{postfix}")
    end

    def write_data(postfix, data)
      DB.write("channel_#{@channel_name}_#{postfix}", data)
    end

    def start_dialog
      task = find_task_by_name("greeting")

      write_data("dialog_sid", random_dialog_string)
      write_data("task", task)

      handle_actions(task.dig("actions", "actions"))
    end

    def handle_actions(actions)
      actions.each do |action| # rubocop:disable Metrics/BlockLength
        case get_action_type(action)
        when "say"
          write_message(action["say"])
        when "redirect"
          handle_redirect_action(action)
          break
        when "listen"
          write_data("action", action)
          break
        when "collect"
          write_data("results", {})
          write_data("action", action)
          write_message(
            action.dig(
              "collect",
              "questions",
              0,
              "question",
            ),
          )
          break
        end
      end
    end

    def handle_redirect_action(action)
      case action["redirect"]
      when String
        task_name = action["redirect"].gsub("task://", "")
        task = find_task_by_name(task_name)

        write_data("task", task)

        handle_actions(task.dig("actions", "actions"))
      when Hash
        dialog_sid = read_data("dialog_sid")
        url = action.dig("redirect", "uri")
        body = {
          DialogueSid: dialog_sid,
        }

        result = Net::HTTP.post_form(
          URI(url),
          body,
        )

        actions = JSON.parse(result.body)["actions"]

        handle_actions(actions)
      end
    end

    def get_action_type(action)
      action.keys.first
    end

    def finish_listen_dialog
      result = read_data("messages").
        reverse.
        detect { |m| m[:author] != "bot" }.
        dig(:body)

      task_names = read_data("action").
        dig("listen", "tasks")

      tasks = task_names.map(&method(:find_task_by_name))
      task = tasks.detect do |t|
        result == t.dig("samples", 0, "taggedText")
      end

      if task
        write_data("task", nil)
        write_data("action", nil)
        write_data("results", nil)

        actions = task.dig(
          "actions",
          "actions",
        )

        handle_actions(actions)
      else
        handle_actions(read_data("task").dig("actions", "actions"))
      end
    end

    def continue_collect_dialog
      task = read_data("action")
      results = read_data("results")
      messages = read_data("messages")

      field_name = task.dig(
        "collect",
        "questions",
        results.keys.count,
        "name",
      )
      results[field_name] = messages.last[:body]

      next_question = task.dig(
        "collect",
        "questions",
        results.keys.count,
        "question",
      )

      if next_question
        write_message(next_question)
        write_data("results", results)
      else
        finish_collect_dialog(results)
      end
    end

    def finish_collect_dialog(results)
      dialog_sid = read_data("dialog_sid")
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

      url = read_data("action").dig(
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

      write_data("task", nil)
      write_data("action", nil)
      write_data("results", nil)

      handle_actions(result_body["actions"])
    end

    def find_task_by_name(name)
      schema.dig("tasks").detect do |task|
        task.dig("uniqueName") == name
      end
    end

    def write_message(message)
      messages = read_data("messages")
      messages.push(
        body: message,
        author: "bot",
        sid: random_message_string,
      )

      write_data("messages", messages)
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
