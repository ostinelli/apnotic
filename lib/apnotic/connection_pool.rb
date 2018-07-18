require 'connection_pool'

module Apnotic

  class ConnectionPool

    class << self
      def new(options={}, pool_options={})
        ::ConnectionPool.new(pool_options) do
          connection = Apnotic::Connection.new(options)
          yield(connection)
          connection
        end
      end

      def development(options={}, pool_options={})
        ::ConnectionPool.new(pool_options) do
          connection = Apnotic::Connection.development(options)
          yield(connection)
          connection
        end
      end
    end
  end
end
