require "buts_oiliwt/version"
require "buts_oiliwt/db"
require "buts_oiliwt/app"

module ButsOiliwt
  class Error < StandardError; end

  DB = Db.instance
end
