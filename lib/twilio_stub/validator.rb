module TwilioStub
  class Validator
    FIRST_NAME = /^[A-Z]\w+$/.freeze
    LAST_NAME = /^[A-Z]\w+$/.freeze
    EMAIL = /^\w+@\w+\.\w{2,4}$/.freeze
    CITY = /^(Kyiv)|(Odessa)|(Lviv)|(New\sYork)|(Saint\sLouis)|(Washington)$/.freeze # rubocop:disable Metrics/LineLength
    COUNTRY = /^(Ukraine)|(USA)|(United\sStates\sof\sAmerica)|(Great\sBritain)$/.freeze # rubocop:disable Metrics/LineLength
    US_STATE = /^(MO)|(CA)|(NY)$/.freeze
    ZIP_CODE = /^\d{5,6}$/.freeze
    PHONE_NUMBER = /^\d{10}$/.freeze
    YES_NO = /^(yes)|(no)$/i.freeze

    def initialize(value, schema, type)
      @value = value
      @schema = schema
      @type = type
    end

    def self.valid?(*args)
      new(*args).valid?
    end

    def valid?
      return validate_by_schema if schema_includes_list?

      !!@value.match(find_matcher)
    end

    private

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

    def find_matcher
      {
        "Twilio.FIRST_NAME" => FIRST_NAME,
        "Twilio.LAST_NAME" => LAST_NAME,
        "Twilio.EMAIL" => EMAIL,
        "Twilio.CITY" => CITY,
        "Twilio.COUNTRY" => COUNTRY,
        "Twilio.US_STATE" => US_STATE,
        "Twilio.ZIP_CODE" => ZIP_CODE,
        "Twilio.PHONE_NUMBER" => PHONE_NUMBER,
        "Twilio.YES_NO" => YES_NO,
      }.fetch(@type) do
        raise "Validation type #{@type} is not supported"
      end
    end
  end
end
