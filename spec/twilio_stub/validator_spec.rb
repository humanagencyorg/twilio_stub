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
  context "when schema has an allowed_values list" do
    context "when value exists in list" do
      it "returns true" do
        value = "A"
        schema = {
          "allowed_values" => {
            "list" => [value],
          },
        }
        type = nil
        result = described_class.valid?(value, schema, type)

        expect(result).to eq(true)
      end
    end
    context "when value does not exist in list" do
      it "returns false" do
        value = "A"
        schema = {
          "allowed_values" => {
            "list" => [],
          },
        }
        type = nil
        result = described_class.valid?(value, schema, type)

        expect(result).to eq(false)
      end
    end
  end
end
