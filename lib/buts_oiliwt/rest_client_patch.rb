require "buts_oiliwt/db"

module ButsOiliwt
  module RestClientPatch
    PREFIX_MATCHER = /https:\/\/([^\.]*)/
    HOST_MATCHER = /https:\/\/[^\/]*/

    private_constant :PREFIX_MATCHER
    private_constant :HOST_MATCHER

    def send(request)
      origin = ButsOiliwt::DB.read("host")

      if origin
        prefix = request.url.match(PREFIX_MATCHER)
        host = origin + "/#{prefix[1]}"
        url = request.url.sub(HOST_MATCHER, host)
      else
        url = request.url
      end

      @connection.send(
        request.method.downcase.to_sym,
        url,
        request.method == "GET" ? request.params : request.data,
      )
    rescue Faraday::Error => e
      raise Twilio::REST::TwilioError, e
    end
  end
end
