require 'net-http2'
require 'openssl'

module Apnotic

  APPLE_DEVELOPMENT_SERVER_URL = "https://api.development.push.apple.com:443"
  APPLE_PRODUCTION_SERVER_URL  = "https://api.push.apple.com:443"

  class Connection
    attr_reader :url, :cert_path

    class << self
      def development(options={})
        options.merge!(url: APPLE_DEVELOPMENT_SERVER_URL)
        new(options)
      end
    end

    def initialize(options={})
      @url             = options[:url] || APPLE_PRODUCTION_SERVER_URL
      @cert_path       = options[:cert_path]
      @cert_pass       = options[:cert_pass]
      @connect_timeout = options[:connect_timeout] || 30
      @auth_method     = options[:auth_method] || :cert
      @team_id         = options[:team_id]
      @key_id          = options[:key_id]
      @first_push      = true

      raise "Cert file not found: #{@cert_path}" unless @cert_path && (@cert_path.respond_to?(:read) || File.exist?(@cert_path))

      @client = NetHttp2::Client.new(@url, ssl_context: ssl_context, connect_timeout: @connect_timeout)
    end

    def push(notification, options={})
      request  = prepare_request(notification)
      response = @client.call(:post, request.path,
        body:    request.body,
        headers: request.headers,
        timeout: options[:timeout]
      )
      Apnotic::Response.new(headers: response.headers, body: response.body) if response
    end

    def push_async(push)
      if @first_push
        @first_push = false
        @client.call_async(push.http2_request)
      else
        delayed_push_async(push)
      end
    end

    def prepare_push(notification)
      request       = prepare_request(notification)
      http2_request = @client.prepare_request(:post, request.path,
        body:    request.body,
        headers: request.headers
      )
      Apnotic::Push.new(http2_request)
    end

    def close
      @client.close
    end

    def join
      @client.join
    end

    def on(event, &block)
      @client.on(event, &block)
    end

    private

    def prepare_request(notification)
      notification.authorization = provider_token if @auth_method == :token
      Apnotic::Request.new(notification)
    end

    def delayed_push_async(push)
      if streams_available?
        @client.call_async(push.http2_request)
      else
        sleep 0.001
        delayed_push_async(push)
      end
    end

    def streams_available?
      remote_max_concurrent_streams - @client.stream_count > 0
    end

    def remote_max_concurrent_streams
      # 0x7fffffff is the default value from http-2 gem (2^31)
      if @client.remote_settings[:settings_max_concurrent_streams] == 0x7fffffff
        0
      else
        @client.remote_settings[:settings_max_concurrent_streams]
      end
    end

    def ssl_context
      @auth_method == :cert ? build_ssl_context : nil
    end

    def build_ssl_context
      @build_ssl_context ||= begin
        ctx = OpenSSL::SSL::SSLContext.new
        begin
          p12      = OpenSSL::PKCS12.new(certificate, @cert_pass)
          ctx.key  = p12.key
          ctx.cert = p12.certificate
        rescue OpenSSL::PKCS12::PKCS12Error
          ctx.key  = OpenSSL::PKey::RSA.new(certificate, @cert_pass)
          ctx.cert = OpenSSL::X509::Certificate.new(certificate)
        end
        ctx
      end
    end

    def certificate
      @certificate ||= begin
        if @cert_path.respond_to?(:read)
          cert = @cert_path.read
          @cert_path.rewind if @cert_path.respond_to?(:rewind)
        else
          cert = File.read(@cert_path)
        end
        cert
      end
    end

    def provider_token
      @provider_token_cache ||= begin
        instance = ProviderToken.new(certificate, @team_id, @key_id)
        InstanceCache.new(instance, :token, 30 * 60)
      end
      @provider_token_cache.call
    end

  end
end
