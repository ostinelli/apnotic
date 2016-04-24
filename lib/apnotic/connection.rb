require 'socket'
require 'openssl'
require 'uri'
require 'http/2'

module Apnotic

  APPLE_PRODUCTION_SERVER_URI = "https://api.push.apple.com:443"

  class Connection
    attr_reader :uri, :cert_path

    def initialize(options={})
      @uri       = URI.parse(options[:uri] || APPLE_PRODUCTION_SERVER_URI)
      @cert_path = options[:cert_path]
      @cert_pass = options[:cert_pass]

      @pipe_r, @pipe_w = Socket.pair(:UNIX, :STREAM, 0)
      @socket_thread   = nil

      raise "URI needs to be a HTTPS address" if uri.scheme != 'https'
      raise "Cert file not found: #{@cert_path}" unless @cert_path && File.exists?(@cert_path)
    end

    def push(notification, &block)
      headers = build_headers_for notification
      body    = notification.body

      h2_stream = h2_stream_with(&block)

      open

      h2_stream.headers(headers, end_stream: false)
      h2_stream.data(body, end_stream: true)
    end

    def close
      exit_thread(@socket_thread)

      @ssl_context = nil
      @h2          = nil
      @read_thread = nil
      @pipe_r      = nil
      @pipe_w      = nil
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

    def h2_stream_with(&block)
      stream = Apnotic::Stream.new(&block)

      h2_stream = h2.new_stream

      h2_stream.on(:headers) do |hs|
        hs.each { |k, v| stream.headers[k] = v }
      end

      h2_stream.on(:data) do |d|
        stream.data << d
      end

      h2_stream.on(:close) do
        stream.trigger_callback
      end

      h2_stream
    end

    def open
      return if @socket_thread

      @socket_thread = Thread.new do

        socket = new_socket

        loop do

          begin
            data_to_send = @pipe_r.read_nonblock(1024)
            socket.write(data_to_send)
          rescue IO::WaitReadable, IO::WaitWritable
          end

          begin
            data_received = socket.read_nonblock(1024)
            h2 << data_received
            break if socket.nil? || socket.closed? || socket.eof?

          rescue IO::WaitReadable
            IO.select([socket, @pipe_r])

          rescue IO::WaitWritable
            IO.select([@pipe_r], [socket])

          end
        end

        socket.close unless socket.closed?

      end.tap { |t| t.abort_on_exception = true }
    end

    def new_socket
      tcp               = TCPSocket.new(@uri.host, @uri.port)
      socket            = OpenSSL::SSL::SSLSocket.new(tcp, ssl_context)
      socket.sync_close = true
      socket.hostname   = @uri.hostname

      socket.connect

      socket
    end

    def ssl_context
      @ssl_context ||= begin
        ctx         = OpenSSL::SSL::SSLContext.new
        certificate = File.read(@cert_path)
        passphrase  = @cert_pass
        ctx.key     = OpenSSL::PKey::RSA.new(certificate, passphrase)
        ctx.cert    = OpenSSL::X509::Certificate.new(certificate)
        ctx
      end
    end

    def h2
      @h2 ||= HTTP2::Client.new.tap do |h2|
        h2.on(:frame) do |bytes|
          @pipe_w.write(bytes)
          @pipe_w.flush
        end
      end
    end

    def exit_thread(thread)
      return unless thread && thread.alive?
      thread.exit
      thread.join
    end
  end
end
