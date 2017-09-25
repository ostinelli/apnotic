require 'apnotic/abstract_notification'

module Apnotic

  class Notification < AbstractNotification
    attr_accessor :alert, :badge, :sound, :content_available, :category, :custom_payload, :url_args, :mutable_content

    private

    def aps
      {}.tap do |result|
        result.merge!(alert: alert) if alert
        result.merge!(badge: badge) if badge
        result.merge!(sound: sound) if sound
        result.merge!(category: category) if category
        result.merge!('content-available' => content_available) if content_available
        result.merge!('url-args' => url_args) if url_args
        result.merge!('mutable-content' => mutable_content) if mutable_content
      end
    end

    def to_hash
      { aps: aps }.tap do |result|
        result.merge!(custom_payload) if custom_payload
      end
    end
  end
end
