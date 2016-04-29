require 'spec_helper'

describe Apnotic::Connection do
  let(:url) { "https://localhost" }
  let(:cert_path) { apn_file_path }
  let(:connection) do
    Apnotic::Connection.new({
      url:       url,
      cert_path: cert_path,
      cert_pass: ""
    })
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
    end
  end

  describe ".development" do
    let(:options) { { url: "will-be-overwritten", other: "options" } }

    it "initializes a connection object with url set to APPLE DEVELOPMENT" do
      expect(Apnotic::Connection).to receive(:new).with(options.merge({
        url: "https://api.development.push.apple.com:443"
      }))

      Apnotic::Connection.development(options)
    end
  end
end
