require_relative "./spec_helper"

require "buts_oiliwt/app"
require "buts_oiliwt/db"

RSpec.describe ButsOiliwt do
  describe ".boot" do
    it "calls App.boot_once" do
      allow(ButsOiliwt::App).to receive(:boot_once)

      described_class.boot

      expect(ButsOiliwt::App).to have_received(:boot_once)
    end
  end

  describe ".twilio_host" do
    it "returns localhost with App's port" do
      allow(ButsOiliwt::App).to receive(:port).and_return(9292)

      expect(described_class.twilio_host).to eq("http://localhost:9292")
    end
  end

  describe ".stub_requests" do
    it "calls webmock to stub twilio requests" do
      webmock = class_double(WebMock::API).as_stubbed_const
      webmock_instance = double("WebMock::API instance")

      allow(webmock).
        to receive(:stub_request).
        with(:any, /twilio.com/).
        and_return(webmock_instance)
      allow(webmock_instance).
        to receive(:to_rack).
        with(ButsOiliwt::App)

      described_class.stub_requests

      expect(webmock).
        to have_received(:stub_request).
        with(:any, /twilio.com/)
      expect(webmock_instance).
        to have_received(:to_rack).
        with(ButsOiliwt::App)
    end
  end

  describe ".clear_store" do
    it "calls DB to clear it" do
      allow(ButsOiliwt::DB).to receive(:clear_all)

      described_class.clear_store

      expect(ButsOiliwt::DB).to have_received(:clear_all)
    end
  end
end
