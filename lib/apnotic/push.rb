module Apnotic

  class Push
    attr_reader :http2_request

    def initialize(http2_request)
      @http2_request = http2_request
      @headers       = {}
      @data          = ''
      @events        = {}

      listen_for_http2_events
    end

    def on(event, &block)
      raise ArgumentError, 'on event must provide a block' unless block_given?

      @events[event] ||= []
      @events[event] << block
    end

    def emit(event, arg)
      return unless @events[event]
      @events[event].each { |b| b.call(arg) }
    end

    private

    def listen_for_http2_events
      @http2_request.on(:headers) { |headers| @headers.merge!(headers) }
      @http2_request.on(:body_chunk) { |chunk| @data << chunk }
      @http2_request.on(:close) do
        response = Apnotic::Response.new(headers: @headers, body: @data)
        emit(:response, response)
      end
    end
  end
end
