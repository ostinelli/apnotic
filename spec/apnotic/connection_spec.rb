require 'spec_helper'

describe Apnotic::Connection do
  let(:uri) { "https://localhost" }
  let(:cert_path) { apn_file_path }
  let(:connection) do
    Apnotic::Connection.new({
      uri:       uri,
      cert_path: cert_path,
      cert_pass: ""
    })
  end

  describe ".new" do

    describe "option: uri" do

      subject { connection.uri }

      context "when uri is not set" do
        let(:uri) { nil }

        it "defaults to APPLE PRODUCTION uri" do
          expect(subject).to be_a URI::HTTPS

          expect(subject.scheme).to eq "https"
          expect(subject.host).to eq "api.push.apple.com"
          expect(subject.port).to eq 443
        end
      end

      context "when uri is set" do

        context "and it is a secure address" do
          let(:uri) { "https://localhost:4343" }

          it "sets it" do
            expect(subject).to be_a URI::HTTPS

            expect(subject.scheme).to eq "https"
            expect(subject.host).to eq "localhost"
            expect(subject.port).to eq 4343
          end
        end

        context "and it is not a secure address" do
          let(:uri) { "http://localhost:4343" }

          it "raises an error" do
            expect { connection }.to raise_error "URI needs to be a HTTPS address"
          end
        end
      end
    end

    describe "option: cert_path" do

      subject { connection.cert_path }

      context "when it points to an existing file" do
        let(:cert_path) { cert_file_path }
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
          p12_connection = Apnotic::Connection.new(uri: uri, cert_path: apn_p12_file_path)
          expect(connection.send(:certificate)).to eq p12_connection.send(:certificate)
        end
      end

      context "when it is a IO object" do
        it "is equivalent to a file path" do
          io_connection = Apnotic::Connection.new(uri: uri, cert_path: StringIO.new(File.read(apn_file_path)))
          expect(connection.send(:certificate)).to eq io_connection.send(:certificate)
        end
      end

    end
  end

  describe ".development" do
    let(:options) { { uri: "will-be-overwritten", other: "options" } }

    it "initializes a connection object with uri set to APPLE DEVELOPMENT" do
      expect(Apnotic::Connection).to receive(:new).with(options.merge({
        uri: "https://api.development.push.apple.com:443"
      }))

      Apnotic::Connection.development(options)
    end
  end

  describe "#push" do
    let(:notification) { double(:notification, token: "token", body: "notification-body") }
    let(:options) { double(:options) }
    let(:h2_stream) { double(:h2_stream) }
    let(:stream) { double(:stream) }
    let(:result) { double(:result) }

    before do
      allow(connection).to receive(:open)
      allow(connection).to receive_message_chain(:h2, :new_stream) { h2_stream }
      allow(Apnotic::Stream).to receive(:new).with(uri: URI.parse(uri), h2_stream: h2_stream) { stream }
    end

    it "sends the stream with the correct headers & data" do
      expect(connection).to receive(:open)
      expect(stream).to receive(:push).with(notification, options) { result }

      expect(connection.push(notification, options)).to eq result
    end
  end
end
