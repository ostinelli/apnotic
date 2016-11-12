require 'connection_pool'

module Apnotic

  class ConnectionPool

    class << self
      def new(options={}, pool_options={})
        ::ConnectionPool.new(pool_options) do
          Apnotic::Connection.new(options)
        end
      end

      def development(options={}, pool_options={})
        ::ConnectionPool.new(pool_options) do
          Apnotic::Connection.development(options)
        end
      end
    end
  end
end
