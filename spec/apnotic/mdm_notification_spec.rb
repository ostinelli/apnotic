require 'spec_helper'

describe Apnotic::MdmNotification do
  let(:token) { 'fake token content' }
  let (:push_magic) { "apple's specific push magic content" }
  let(:notification) { Apnotic::MdmNotification.new(token: token, push_magic: push_magic) }

  describe "attributes" do

    subject { notification }

    # <https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/APNsProviderAPI.html>
    describe "remote mdm notification payload" do
      it { is_expected.to have_attributes(token: token) }
    end

    # <https://developer.apple.com/library/content/documentation/Miscellaneous/Reference/MobileDeviceManagementProtocolRef/3-MDM_Protocol/MDM_Protocol.html#//apple_ref/doc/uid/TP40017387-CH3-SW3>
    describe "request specifics" do
      it { is_expected.to have_attributes(push_magic: push_magic) }
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
    it { is_expected.to eq ({ mdm: push_magic }.to_json) }
  end
end
