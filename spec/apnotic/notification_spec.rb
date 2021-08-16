require 'spec_helper'

describe Apnotic::Notification do
  let(:notification) { Apnotic::Notification.new("token") }

  describe "attributes" do

    subject { notification }

    # <https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/generating_a_remote_notification#2943363>
    describe "remote notification payload" do

      before do
        notification.alert              = "Something for you!"
        notification.badge              = 22
        notification.sound              = "sound.wav"
        notification.content_available  = false
        notification.category           = "action_one"
        notification.thread_id          = "action_id"
        notification.target_content_id  = "target_content_id"
        notification.interruption_level = "passive"
        notification.relevance_score    = 0.8
        notification.custom_payload     = { acme1: "bar" }
      end

      it { is_expected.to have_attributes(token: "token") }
      it { is_expected.to have_attributes(alert: "Something for you!") }
      it { is_expected.to have_attributes(badge: 22) }
      it { is_expected.to have_attributes(sound: "sound.wav") }
      it { is_expected.to have_attributes(content_available: false) }
      it { is_expected.to have_attributes(category: "action_one") }
      it { is_expected.to have_attributes(thread_id: "action_id") }
      it { is_expected.to have_attributes(target_content_id: "target_content_id") }
      it { is_expected.to have_attributes(interruption_level: "passive") }
      it { is_expected.to have_attributes(relevance_score: 0.8) }
      it { is_expected.to have_attributes(custom_payload: { acme1: "bar" }) }
    end

    # <https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/APNsProviderAPI.html>
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

    context "when nothing is specified" do

      it { is_expected.to eq (
        {
          aps: {}
        }.to_json
      ) }
    end

    context "when only alert is specified" do

      before do
        notification.alert = "Something for you!"
      end

      it { is_expected.to eq (
        {
          aps: {
            alert: "Something for you!"
          }
        }.to_json
      ) }
    end

    context "when everything is specified" do

      before do
        notification.alert              = "Something for you!"
        notification.badge              = 22
        notification.sound              = "sound.wav"
        notification.content_available  = 1
        notification.category           = "action_one"
        notification.thread_id          = 'action_id'
        notification.target_content_id  = "target_content_id"
        notification.interruption_level = "passive"
        notification.relevance_score    = 0.8
        notification.custom_payload     = { acme1: "bar" }
        notification.mutable_content    = 1
      end

      it { is_expected.to eq (
        {
          aps: {
            alert:             "Something for you!",
            badge:             22,
            sound:             "sound.wav",
            category:          "action_one",
            'content-available'  => 1,
            'mutable-content'    => 1,
            'thread-id'          => 'action_id',
            'target-content-id'  => 'target_content_id',
            'interruption-level' => 'passive',
            'relevance-score'    => 0.8
          },
          acme1: "bar"
        }.to_json
      ) }
    end

    context "when sending Safari push notifications" do

      before do
        notification.alert = {
          title: "Flight A998 Now Boarding",
          body: "Boarding has begun for Flight A998.",
          action: "View"
        }
        notification.url_args = [1, 2]
      end

      it { is_expected.to eq (
        {
          aps:   {
            alert: {
              title: "Flight A998 Now Boarding",
              body: "Boarding has begun for Flight A998.",
              action: "View"
            },
            'url-args' => [1, 2]
          }
        }.to_json
      ) }
    end
  end

  describe "#background_notification?" do
    subject { notification.background_notification? }

    context "when content-available is not set" do
      before do
        notification.alert = "An alert"
      end

      it { expect(subject).to eq false }
    end

    context "when only content-available is set to 1" do
      before do
        notification.content_available = 1
      end

      it { expect(subject).to eq true }
    end

    context "when only content-available is set to 0" do
      before do
        notification.content_available = 0
      end

      it { expect(subject).to eq false }
    end

    context "when content-available is set to 1 with others attributes" do
      before do
        notification.alert = "An alert"
        notification.content_available = 1
      end

      it { expect(subject).to eq false }
    end
  end
end
