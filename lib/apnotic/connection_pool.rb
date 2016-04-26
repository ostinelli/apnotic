require 'connection_pool'

module Apnotic

  class ConnectionPool

    def self.new(options={}, pool_options={})
      ::ConnectionPool.new(pool_options) do
        Apnotic::Connection.new(options)
      end
    end
  end
end
