module Apnotic

  class Stream
    attr_accessor :headers, :data
    attr_reader :sent_at

    def initialize(&block)
      @block   = block
      @headers = {}
      @data    = ''
      @sent_at = Time.now.utc
    end

    def trigger_callback
      response = Apnotic::Response.new(
        headers: headers,
        body:    data
      )
      trigger_callback_with response
    end

    def trigger_timeout
      trigger_callback_with nil
    end

    private

    def trigger_callback_with(response)
      @block.call(response) if @block
    end
  end
end
