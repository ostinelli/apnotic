require 'spec_helper'

describe Apnotic::Connection do
  let(:url) { "https://localhost" }
  let(:cert_path) { apn_file_path }
  let(:proxy_settings) {
    {
      proxy_addr: "http://proxy",
      proxy_port: "8080",
      proxy_user: "proxy-user",
      proxy_pass: "proxy-pass"
    }
  }
  let(:connection) do
    Apnotic::Connection.new({
      url:       url,
      cert_path: cert_path
    })
  end
  let(:connection_proxy) do
    Apnotic::Connection.new({
      url:       url,
      cert_path: cert_path
    }.merge(proxy_settings))
  end

  describe ".new" do

    describe "option: url" do

      subject { connection.url }

      context "when url is not set" do
        let(:url) { nil }

        it "defaults to APPLE PRODUCTION url" do
          expect(subject).to eq "https://api.push.apple.com:443"
        end
      end

      context "when url is set" do
        let(:url) { "https://localhost:4343" }

        it { is_expected.to eq "https://localhost:4343" }
      end
    end

    describe "option: cert_path" do

      subject { connection.cert_path }

      context "when it points to an existing file" do
        let(:cert_path) { apn_file_path }
        it { is_expected.to eq cert_path }
      end

      context "when it points to an non-existant file" do
        let(:cert_path) { "/non-existant.crt" }

        it "raises an error" do
          expect { connection }.to raise_error "Cert file not found: /non-existant.crt"
        end
      end

      context "when it is a p12 file" do
        it "is equivalent to a pem file" do
          p12_connection = Apnotic::Connection.new(url: url, cert_path: apn_p12_file_path)
          expect(connection.send(:ssl_context).key.to_pem).to eq p12_connection.send(:ssl_context).key.to_pem
          expect(connection.send(:ssl_context).cert.to_pem).to eq p12_connection.send(:ssl_context).cert.to_pem
        end
      end

      context "when it is a IO object" do
        it "is equivalent to a file path" do
          io_connection = Apnotic::Connection.new(url: url, cert_path: StringIO.new(File.read(apn_file_path)))
          expect(connection.send(:ssl_context).key.to_pem).to eq io_connection.send(:ssl_context).key.to_pem
          expect(connection.send(:ssl_context).cert.to_pem).to eq io_connection.send(:ssl_context).cert.to_pem
        end
      end
    end

    describe "option: proxy family" do
      context "when proxy is set" do
        it "has proxy-assigned NetHttp2 instance" do
          client = connection_proxy.instance_variable_get(:@client)
          proxy_settings.each do |k, v|
            expect(client.instance_variable_get("@#{k}")).to eq v
          end
        end
      end
    end
  end

  describe ".development" do
    let(:options) { { url: "will-be-overwritten", other: "options" } }

    subject { Apnotic::Connection.development(cert_path: cert_path) }

    it "initializes a connection object with url set to APPLE DEVELOPMENT" do
      expect(Apnotic::Connection).to receive(:new).with(options.merge({
        url: "https://api.sandbox.push.apple.com:443"
      }))

      Apnotic::Connection.development(options)
    end

    it "responds to development?" do
      expect(subject.send(:development?)).to eq true
    end
  end

  describe "#on" do

    it "attaches the event to the underlying client" do
      exception = nil
      connection.on(:error) { |exc| exception = exc }

      error = StandardError.new("my test error")
      connection.instance_variable_get(:@client).emit(:error, error)

      expect(exception).to eq error
    end
  end
end
