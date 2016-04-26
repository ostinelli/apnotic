require 'spec_helper'

describe Apnotic::Stream do
  let(:h2_stream) do
    s = double(:h2_stream)
    allow(s).to receive(:on)
    s
  end
  let(:uri) { URI.parse("https://localhost:443") }
  let(:stream) { Apnotic::Stream.new(h2_stream: h2_stream, uri: uri) }

  describe "#push" do
    let(:notification) { double(:notification, token: "token", body: "notification-body") }
    let(:options) { double(:options) }
    let(:headers) { double(:headers) }
    let(:respond) { double(:respond) }

    before do
      allow(stream).to receive(:build_headers_for).with(notification) { headers }
      allow(stream).to receive(:new_stream) { stream }
      allow(stream).to receive(:respond).with(options) { respond }
    end

    it "sends the stream with the correct headers & data" do
      expect(h2_stream).to receive(:headers).with(headers, { end_stream: false })
      expect(h2_stream).to receive(:data).with("notification-body", { end_stream: true })

      result = stream.push(notification, options)
      expect(result).to eq respond
    end
  end

  describe "#build_headers_for" do
    let(:notification_body) { "notification-body" }
    let(:notification) do
      notification            = Apnotic::Notification.new("phone-token")
      notification.id         = "apns-id"
      notification.expiration = 1461491082
      notification.priority   = 10
      notification.topic      = "com.example.myapp"
      notification
    end

    def build_headers
      stream.send(:build_headers_for, notification)
    end

    before { allow(notification).to receive(:body) { notification_body } }

    subject { build_headers }

    it { is_expected.to eq (
      {
        ":scheme"         => "https",
        ":method"         => "POST",
        ":path"           => "/3/device/phone-token",
        "host"            => "localhost",
        "content-length"  => "17",
        "apns-id"         => "apns-id",
        "apns-expiration" => 1461491082,
        "apns-priority"   => 10,
        "apns-topic"      => "com.example.myapp"
      }
    ) }
  end
end
