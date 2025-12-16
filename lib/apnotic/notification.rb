require 'apnotic/abstract_notification'

module Apnotic

  class Notification < AbstractNotification
    attr_accessor :alert, :badge, :sound, :content_available, :category, :custom_payload, :url_args, :mutable_content, :thread_id
    attr_accessor :target_content_id, :interruption_level, :relevance_score
    attr_accessor :stale_date, :content_state, :timestamp, :event, :dismissal_date

    def background_notification?
      aps.count == 1 && aps.key?('content-available') && aps['content-available'] == 1
    end

    private

    def aps
      @aps ||= {}.tap do |result|
        result.merge!(alert: alert) if alert
        result.merge!(badge: badge) if badge
        result.merge!(sound: sound) if sound
        result.merge!(category: category) if category
        result.merge!('content-available' => content_available) if content_available
        result.merge!('url-args' => url_args) if url_args
        result.merge!('mutable-content' => mutable_content) if mutable_content
        result.merge!('thread-id' => thread_id) if thread_id
        result.merge!('target-content-id' => target_content_id) if target_content_id
        result.merge!('interruption-level' => interruption_level) if interruption_level
        result.merge!('relevance-score' => relevance_score) if relevance_score
        result.merge!('stale-date' => stale_date) if stale_date
        result.merge!('content-state' => content_state) if content_state
        result.merge!('timestamp' => timestamp) if timestamp
        result.merge!('event' => event) if event
        result.merge!('dismissal-date' => dismissal_date) if dismissal_date
      end
    end

    def to_hash
      { aps: aps }.tap do |result|
        result.merge!(custom_payload) if custom_payload
      end
    end
  end
end
