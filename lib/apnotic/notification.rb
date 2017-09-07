require 'securerandom'
require 'json'

module Apnotic

  class Notification
    attr_reader :token
    attr_accessor :alert, :badge, :sound, :content_available, :category, :custom_payload, :url_args, :mutable_content
    attr_accessor :apns_id, :expiration, :priority, :topic, :apns_collapse_id, :authorization

    def initialize(token)
      @token   = token
      @apns_id = SecureRandom.uuid
    end

    def body
      JSON.dump(to_hash).force_encoding(Encoding::BINARY)
    end

    def authorization_header
      authorization ? "bearer #{authorization}" : nil
    end

    private

    def to_hash
      aps = {}

      aps.merge!(alert: alert) if alert
      aps.merge!(badge: badge) if badge
      aps.merge!(sound: sound) if sound
      aps.merge!(category: category) if category
      aps.merge!('content-available' => content_available) if content_available
      aps.merge!('url-args' => url_args) if url_args
      aps.merge!('mutable-content' => mutable_content) if mutable_content

      n = { aps: aps }
      n.merge!(custom_payload) if custom_payload
      n
    end
  end
end
