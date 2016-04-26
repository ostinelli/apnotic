module Apnotic

  class Stream
    attr_reader :h2_stream

    def initialize(options={})
      @h2_stream = options[:h2_stream]
      @headers   = {}
      @data      = ''
      @completed = false
      @mutex     = Mutex.new
      @cv        = ConditionVariable.new

      @h2_stream.on(:headers) do |hs|
        hs.each { |k, v| @headers[k] = v }
      end

      @h2_stream.on(:data) { |d| @data << d }
      @h2_stream.on(:close) do
        @mutex.synchronize do
          @completed = true
          @cv.signal
        end
      end
    end

    def response(options={})
      @mutex.synchronize { @cv.wait(@mutex, options[:timeout]) }

      if @completed
        Apnotic::Response.new(
          headers: @headers,
          body:    @data
        )
      else
        nil
      end
    end
  end
end
