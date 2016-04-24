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

    class Response
      attr_accessor :body, :headers

      def initialize
        @headers = { ":status" => "200" }
        @body    = ''
      end
    end

    class Server
      include Apnotic::ApiHelpers

      attr_accessor :on_req

      def initialize(options={})
        @port          = options[:port]
        @listen_thread = nil
      end

      def listen
        @listen_thread = Thread.new do
          s      = TCPServer.new(@port)
          server = OpenSSL::SSL::SSLServer.new(s, ssl_context)

          loop do
            sock = server.accept
            handle(sock)
          end
        end.tap { |t| t.abort_on_exception = true }
      end

      def stop
        exit_thread(@listen_thread)
        @listen_thread = nil
      end

      private

      def handle(sock)
        conn = HTTP2::Server.new

        conn.on(:frame) { |bytes| sock.write(bytes) }

        conn.on(:stream) do |stream|
          req = Request.new

          stream.on(:headers) { |h| req.import_headers(h) }
          stream.on(:data) { |d| req.body << d }
          stream.on(:half_close) do
            # callbacks
            res = on_req.call(req) if on_req
            res = Response.new unless res.is_a?(Response)

            stream.headers({
              ':status'        => res.headers[":status"],
              'content-length' => res.body.bytesize.to_s,
              'content-type'   => 'text/plain',
            }, end_stream: false)

            stream.data(res.body, end_stream: true)
          end
        end

        while sock && !sock.closed? && !sock.eof?
          data = sock.read_nonblock(1024)
          conn << data
        end

        sock.close unless sock.closed?
      end

      def ssl_context
        ctx      = OpenSSL::SSL::SSLContext.new
        ctx.cert = OpenSSL::X509::Certificate.new(File.open(cert_file_path))
        ctx.key  = OpenSSL::PKey::RSA.new(File.open(key_file_path))
        ctx
      end

      def exit_thread(thread)
        return unless thread && thread.alive?
        thread.exit
        thread.join
      end
    end
  end
end
