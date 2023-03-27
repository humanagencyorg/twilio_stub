module TwilioStub
  class Validator
    FIRST_NAME = /^[A-Z]\w+$/
    LAST_NAME = /^[A-Z]\w+$/
    EMAIL = /^\w+@\w+\.\w{2,4}$/
    CITY = /^(Kyiv)|(Odessa)|(Lviv)|(New\sYork)|(Saint\sLouis)|(Washington)$/ # rubocop:disable Layout/LineLength
    COUNTRY = /^(Ukraine)|(USA)|(United\sStates\sof\sAmerica)|(Great\sBritain)$/ # rubocop:disable Layout/LineLength
    US_STATE = /^(MO)|(CA)|(NY)$/
    ZIP_CODE = /^\d{5,6}$/
    PHONE_NUMBER = /^\d{10}$/
    YES_NO = /^(yes)|(no)$/i
    MATCHERS = {
      "Twilio.FIRST_NAME" => FIRST_NAME,
      "Twilio.LAST_NAME" => LAST_NAME,
      "Twilio.EMAIL" => EMAIL,
      "Twilio.CITY" => CITY,
      "Twilio.COUNTRY" => COUNTRY,
      "Twilio.US_STATE" => US_STATE,
      "Twilio.ZIP_CODE" => ZIP_CODE,
      "Twilio.PHONE_NUMBER" => PHONE_NUMBER,
      "Twilio.YES_NO" => YES_NO,
    }.freeze

    def initialize(value, schema, type)
      @value = value
      @schema = schema
      @type = type
    end

    def self.valid?(*args)
      new(*args).valid?
    end

    def valid?
      if validated_by_webhook?
        response = Net::HTTP.post_form(
          URI(@schema["webhook"]["url"]),
          { "ValidateFieldAnswer" => @value },
        )

        result = JSON.parse(response.body)["valid"]

        return result
      end

      return validate_by_schema if schema_includes_list?

      matcher = MATCHERS[@type]

      return true unless matcher

      !!@value.match(matcher)
    end

    private

    def validated_by_webhook?
      @schema.is_a?(Hash) && @schema["webhook"]
    end

    def schema_includes_list?
      return false unless @schema.is_a?(Hash)
      return false unless @schema.dig("allowed_values", "list").is_a?(Array)

      true
    end

    def validate_by_schema
      @schema.
        dig("allowed_values", "list").
        include?(@value)
    end
  end
end
