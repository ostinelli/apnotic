require 'securerandom'
require 'json'

module Apnotic

  class Notification
    attr_reader :token
    attr_accessor :alert, :badge, :sound, :content_available, :category, :custom_payload, :url_args
    attr_accessor :apns_id, :expiration, :priority, :topic

    def initialize(token)
      @token   = token
      @apns_id = SecureRandom.uuid
    end

    def body
      JSON.dump(to_hash).force_encoding(Encoding::BINARY)
    end

    private

    def to_hash
      aps = { alert: alert }
      aps.merge!(badge: badge) if badge
      aps.merge!(sound: sound) if sound
      aps.merge!(content_available: content_available) if content_available
      aps.merge!(category: category) if category
      aps.merge!('url-args' => url_args) if url_args

      n = { aps: aps }
      n.merge!(custom_payload) if custom_payload
      n
    end
  end
end
