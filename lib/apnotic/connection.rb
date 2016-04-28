require 'socket'
require 'openssl'
require 'uri'
require 'http/2'

module Apnotic

  APPLE_DEVELOPMENT_SERVER_URI = "https://api.development.push.apple.com:443"
  APPLE_PRODUCTION_SERVER_URI  = "https://api.push.apple.com:443"

  class Connection
    attr_reader :uri, :cert_path

    class << self
      def development(options={})
        options.merge!(uri: APPLE_DEVELOPMENT_SERVER_URI)
        new(options)
      end
    end

    def initialize(options={})
      @uri       = URI.parse(options[:uri] || APPLE_PRODUCTION_SERVER_URI)
      @cert_path = options[:cert_path]
      @cert_pass = options[:cert_pass]

      @pipe_r, @pipe_w = Socket.pair(:UNIX, :STREAM, 0)
      @socket_thread   = nil
      @mutex           = Mutex.new

      raise "URI needs to be a HTTPS address" if uri.scheme != 'https'
      raise "Cert file not found: #{@cert_path}" unless @cert_path && (@cert_path.respond_to?(:read) || File.exist?(@cert_path))
    end

    def push(notification, options={})
      open

      new_stream.push(notification, options)
    end

    def close
      exit_thread(@socket_thread)

      @ssl_context   = nil
      @h2            = nil
      @pipe_r        = nil
      @pipe_w        = nil
      @socket_thread = nil
    end

    private

    def new_stream
      Apnotic::Stream.new(uri: @uri, h2_stream: h2.new_stream)
    end

    def open
      return if @socket_thread

      @socket_thread = Thread.new do

        socket = new_socket

        begin
          thread_loop(socket)
        ensure
          socket.close unless socket.closed?
          @socket_thread = nil
        end
      end.tap { |t| t.abort_on_exception = true }
    end

    def thread_loop(socket)
      loop do

        available = socket.pending
        if available > 0
          data_received = socket.sysread(available)
          h2 << data_received
          break if socket.closed?
        end

        ready = IO.select([socket, @pipe_r])

        if ready[0].include?(@pipe_r)
          data_to_send = @pipe_r.read_nonblock(1024)
          socket.write(data_to_send)
        end

        if ready[0].include?(socket)
          data_received = socket.read_nonblock(1024)
          h2 << data_received
          break if socket.closed?
        end
      end
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
        cert        = certificate
        passphrase  = @cert_pass
        ctx.key     = OpenSSL::PKey::RSA.new(cert, passphrase)
        ctx.cert    = OpenSSL::X509::Certificate.new(cert)
        ctx
      end
    end

    def h2
      @h2 ||= HTTP2::Client.new.tap do |h2|
        h2.on(:frame) do |bytes|
          @mutex.synchronize do
            @pipe_w.write(bytes)
            @pipe_w.flush
          end
        end
      end
    end

    def exit_thread(thread)
      return unless thread && thread.alive?
      thread.exit
      thread.join
    end

    def certificate
      @certificate ||= begin
        if @cert_path.respond_to?(:read)
          cert = @cert_path.read
          @cert_path.rewind if @cert_path.respond_to?(:rewind)
        else
          cert = File.read(@cert_path)
        end
        begin
          cert = OpenSSL::PKCS12.new(cert, @cert_pass)
          cert = cert.certificate.to_pem + cert.key.to_pem
          @cert_pass = nil
        rescue OpenSSL::PKCS12::PKCS12Error
        end
        cert
      end
    end

  end
end
