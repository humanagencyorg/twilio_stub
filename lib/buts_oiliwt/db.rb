require "pstore"
require "singleton"

module ButsOiliwt
  class Db
    FILENAME = "twilio-stub.store".freeze

    include Singleton

    def initialize
      @db = PStore.new(FILENAME, true)
    end

    def write(name, value)
      @db.transaction { @db[name] = value }
    end

    def read(name)
      @db.transaction(true) { @db[name] }
    end

    def delete(name)
      @db.transaction { @db.delete(name) }
    end

    def clear_all
      File.delete(FILENAME) if File.exist?(FILENAME)
    end
  end
end
