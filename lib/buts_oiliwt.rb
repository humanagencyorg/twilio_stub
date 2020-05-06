require "buts_oiliwt/version"
require "buts_oiliwt/db"
require "buts_oiliwt/app"
require "buts_oiliwt/rest_client_patch"

module ButsOiliwt
  class Error < StandardError; end

  DB = Db.instance
end
