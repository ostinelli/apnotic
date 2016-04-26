module Apnotic

  class Stream

    def initialize(options={})
      @h2_stream = options[:h2_stream]
      @uri       = options[:uri]
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

    def push(notification, options={})
      headers = build_headers_for notification
      body    = notification.body

      @h2_stream.headers(headers, end_stream: false)
      @h2_stream.data(body, end_stream: true)

      respond(options)
    end

    private

    def build_headers_for(notification)
      headers = {
        ':scheme'        => @uri.scheme,
        ':method'        => 'POST',
        ':path'          => "/3/device/#{notification.token}",
        'host'           => @uri.host,
        'content-length' => notification.body.bytesize.to_s
      }
      headers.merge!('apns-id' => notification.id) if notification.id
      headers.merge!('apns-expiration' => notification.expiration) if notification.expiration
      headers.merge!('apns-priority' => notification.priority) if notification.priority
      headers.merge!('apns-topic' => notification.topic) if notification.topic
      headers
    end

    def respond(options={})
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
