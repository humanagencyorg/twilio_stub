require "spec_helper"

RSpec.describe TwilioStub::Validator do
  context "when value hasn't a type" do
    it "returns true" do
      value = "Developer" # Occupation has no type
      schema = {}
      type = nil

      result = described_class.valid?(value, schema, type)

      expect(result).to eq(true)
    end
  end
end
