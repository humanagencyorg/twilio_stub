require "socket"
require "capybara"
require "capybara/server"

module TwilioStub
  module Bootable
    def boot_once
      @boot_once ||= boot
    end

    def port
      @port ||= find_available_port
    end

    private

    def boot
      instance = new

      Capybara::Server.
        new(instance, port:).
        tap(&:boot)
    end

    def find_available_port
      server = TCPServer.new(0)
      server.addr[1]
    ensure
      server&.close
    end
  end
end
