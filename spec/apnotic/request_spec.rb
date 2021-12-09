require 'spec_helper'

describe Apnotic::Request do
  let(:request) { Apnotic::Request.new(notification) }

  describe ".new" do
    let(:notification) { Apnotic::Notification.new("phone-token") }
    let(:request) { Apnotic::Request.new(notification) }
    let(:headers) { double(:headers) }
    let(:body) { double(:body) }

    before do
      allow_any_instance_of(Apnotic::Request).to receive(:build_headers_for).with(notification) { headers }
      allow(notification).to receive(:body) { body }
    end

    it "initializes a response with the correct attributes" do
      expect(request.path).to eq "/3/device/phone-token"
      expect(request.headers).to eq headers
      expect(request.body).to eq body
    end
  end

  describe "#build_headers_for" do
    let(:notification) do
      n                  = Apnotic::Notification.new("phone-token")
      n.apns_id          = "apns-id"
      n.expiration       = "1461491082"
      n.priority         = "10"
      n.topic            = "com.example.myapp"
      n.apns_collapse_id = "collapse-id"
      n
    end

    def build_headers
      request.send(:build_headers_for, notification)
    end

    subject { build_headers }

    context "when it's an alert notification" do
      it { is_expected.to eq (
        {
          "apns-id"          => "apns-id",
          "apns-expiration"  => "1461491082",
          "apns-priority"    => "10",
          "apns-push-type"   => "alert",
          "apns-topic"       => "com.example.myapp",
          "apns-collapse-id" => "collapse-id"
        }
      ) }
    end

    context "when it's a background notification" do
      before do
        notification.content_available = 1
      end

      it { is_expected.to eq (
        {
          "apns-id"          => "apns-id",
          "apns-expiration"  => "1461491082",
          "apns-priority"    => "10",
          "apns-push-type"   => "background",
          "apns-topic"       => "com.example.myapp",
          "apns-collapse-id" => "collapse-id"
        }
      ) }
    end
  end
  
  context 'when it''s a voip notification' do
    before do
      notification.custom_headers = {
        'apns-push-type' => 'voip'
      }
    end

    it do
      is_expected.to eq(
        'apns-id' => 'apns-id',
        'apns-expiration' => '1461491082',
        'apns-priority' => '10',
        'apns-push-type' => 'voip',
        'apns-topic' => 'com.example.myapp',
        'apns-collapse-id' => 'collapse-id'
      )
    end
  end
end
