require 'spec_helper'

describe Apnotic::AbstractNotification do
  let(:notification) { Apnotic::AbstractNotification.new("token") }

  describe "attributes" do
    subject { notification }

    describe "remote abstract notification payload" do
      it { is_expected.to have_attributes(token: "token") }
    end

    describe "request specifics" do
      before do
        notification.apns_id            = "apns-id"
        notification.expiration         = 1461491082
        notification.priority           = 10
        notification.topic              = "com.example.myapp"
        notification.apns_collapse_id   = "collpase-id"
        notification.authorization      = "token"
      end

      it { is_expected.to have_attributes(apns_id: "apns-id") }
      it { is_expected.to have_attributes(expiration: 1461491082) }
      it { is_expected.to have_attributes(priority: 10) }
      it { is_expected.to have_attributes(topic: "com.example.myapp") }
      it { is_expected.to have_attributes(authorization: "token") }
      it { is_expected.to have_attributes(authorization_header: "bearer token") }
    end
  end


  describe "#apns_id" do
    before { allow(SecureRandom).to receive(:uuid) { "an-auto-generated-uid" } }

    it "is initialized as an UUID" do
      expect(notification.apns_id).to eq "an-auto-generated-uid"
    end
  end


  describe "#body" do
    subject { notification.body }

    it { expect { subject }.to raise_error(NotImplementedError) }
  end
end
