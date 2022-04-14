require "net/http"
require "uri"

require "twilio_stub/db"
require "twilio_stub/validator"

module TwilioStub
  class DialogResolver
    def initialize(channel_name, async: nil, target: nil, body: nil)
      @channel_name = channel_name
      @target = target
      @async_task = async
      @body = body
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
      # NOTE: Looking for chatbot task here. If client did not specify target,
      # but there is a message body, we are checking if message body
      # is a keyword that can identify target task
      task = find_task_by_sample if @target.nil? && @body
      task ||= find_task_by_name(@target || "greeting")

      write_data("dialog_sid", random_dialog_string)
      write_data("task", task)

      handle_actions(task.dig("actions", "actions"))
    end

    def find_task_by_sample
      TwilioStub::DB.read("schema")["tasks"].detect do |task|
        task["samples"]&.any? { |sample| sample["TaggedText"] == @body }
      end
    end

    def handle_actions(actions)
      actions.each do |action| # rubocop:disable Metrics/BlockLength
        case get_action_type(action)
        when "say"
          write_message(action["say"])
        when "show"
          write_media(action)
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
        user_id = read_data("user_id")
        url = action.dig("redirect", "uri")
        body = {
          Memory: { twilio: { "custom.#{@channel_name}" => {} } }.to_json,
          DialogueSid: dialog_sid,
          UserIdentifier: user_id,
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
        detect { |m| m[:author] != "bot" }[:body]

      task_names = read_data("action").
        dig("listen", "tasks")

      tasks = task_names.map(&method(:find_task_by_name))
      task = tasks.detect do |t|
        result == t.dig("samples", 0, "TaggedText")
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

      field = task.dig(
        "collect",
        "questions",
        results.keys.count,
      )

      if field["validate"]
        process_collect_with_validation(task, field, results)
      else
        process_collect(task, field, results)
      end
    end

    def process_collect(task, field, results)
      messages = read_data("messages")
      results[field["name"]] = messages.last[:body]

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

    def process_collect_with_validation(task, field, results)
      messages = read_data("messages")
      result = messages.last[:body]
      validation = prepare_validate_attr(field)

      if Validator.valid?(result, field["validate"], field["type"])
        if validation["on_success"]
          handle_actions([validation["on_success"]])
        end

        results[field["name"]] = result

        next_question = task.dig(
          "collect",
          "questions",
          results.keys.count,
          "question",
        )
        write_data("error_index", nil)

        if next_question
          write_message(next_question)
          write_data("results", results)
        else
          finish_collect_dialog(results)
        end
      else
        handle_collect_failure(field)
      end
    end

    def prepare_validate_attr(field)
      validation = field["validate"]
      validation = {} if validation == true
      validation
    end

    def handle_collect_failure(field)
      validation = prepare_validate_attr(field)
      error_index = read_data("error_index") || 0
      defaults = schema.dig(
        "styleSheet",
        "style_sheet",
        "collect",
        "validate",
        "on_failure",
      )
      to_repeat = defaults["repeat_question"]

      if validation["on_failure"]
        actions = validation.dig("on_failure", "messages")
        to_repeat = validation.dig(
          "on_failure",
          "repeat_question",
        ) || to_repeat
      else
        actions = defaults["messages"]
      end

      action = actions[error_index]

      unless action
        error_index = 0
        action = actions[error_index]
      end

      handle_actions([action])
      write_data("error_index", error_index + 1)

      if to_repeat
        handle_actions([{ "say" => field["question"] }])
      end
    end

    def finish_collect_dialog(results)
      dialog_sid = read_data("dialog_sid")
      user_id = read_data("user_id")
      body_results = results.transform_values do |v|
        { answer: v }
      end

      current_input = read_data("messages").last[:body]

      body = {
        DialogueSid: dialog_sid,
        UserIdentifier: user_id,
        CurrentInput: current_input,
        Memory: {
          twilio: {
            "custom.#{@channel_name}" => {},
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
      schema["tasks"].detect do |task|
        task["uniqueName"] == name
      end
    end

    def write_message(message)
      message = {
        body: message,
        author: "bot",
        sid: random_message_string,
      }

      push_message(message)
    end

    def write_media(action)
      url = action["show"]["images"].first["url"]
      body = action["show"]["body"]
      public_id = url.split("/").last.split(".").first
      parent_url = TwilioStub.media_mapper[public_id]
      message = {
        body: body,
        mediaUrl: parent_url,
        author: "bot",
        sid: random_message_string,
      }

      push_message(message)
    end

    def push_message(message)
      messages = read_data("messages")
      messages.push(message)

      write_data("messages", messages)
      @async_task&.sleep(0.5)
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
