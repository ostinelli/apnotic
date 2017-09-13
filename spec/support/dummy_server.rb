require_relative 'api_helpers'

module Apnotic

  module Dummy

    class Request
      attr_accessor :body
      attr_reader :headers

      def initialize
        @body = ''
      end

      def import_headers(h)
        @headers = Hash[*h.flatten]
      end
    end

    class Server
      include Apnotic::ApiHelpers

      attr_accessor :on_req

      def initialize(options={})
        @port          = options[:port]
        @listen_thread = nil
        @threads       = []
      end

      def listen
        @server = new_server

        @listen_thread = Thread.new do
          loop do
            Thread.start(@server.accept) do |socket|
              @threads << Thread.current
              handle(socket)
            end
          end
        end.tap { |t| t.abort_on_exception = true }
      end

      def stop
        exit_thread(@listen_thread)
        @threads.each { |t| exit_thread(t) }

        @server.close

        @server        = nil
        @ssl_context   = nil
        @listen_thread = nil
        @threads       = []
      end

      private

      def handle(socket)
        conn = HTTP2::Server.new(settings_max_concurrent_streams: 1)

        conn.on(:frame) { |bytes| socket.write(bytes) }

        conn.on(:stream) do |stream|
          req = Request.new

          stream.on(:headers) { |h| req.import_headers(h) }
          stream.on(:data) { |d| req.body << d }
          stream.on(:half_close) do
            # callbacks
            res = on_req.call(req) if on_req
            res = NetHttp2::Response.new(
              headers: { ":status" => "200" },
              body:    "response body"
            ) unless res.is_a?(Response)

            stream.headers({
              ':status'        => res.headers[":status"],
              'content-length' => res.body.bytesize.to_s,
              'content-type'   => 'text/plain',
            }, end_stream: false)

            stream.data(res.body, end_stream: true)
          end
        end

        while socket && !socket.closed? && !socket.eof?
          data = socket.read_nonblock(1024)
          conn << data
        end

        socket.close unless socket.closed?
      end

      def new_server
        s = TCPServer.new(@port)
        OpenSSL::SSL::SSLServer.new(s, ssl_context)
      end

      def ssl_context
        @ssl_context ||= begin
          ctx      = OpenSSL::SSL::SSLContext.new
          ctx.cert = OpenSSL::X509::Certificate.new(File.open(server_cert_file_path))
          ctx.key  = OpenSSL::PKey::RSA.new(File.open(server_key_file_path))
          ctx
        end
      end

      def exit_thread(thread)
        return unless thread && thread.alive?
        thread.exit
        thread.join
      end
    end
  end
end
