module Apnotic

  class Request
    attr_reader :path, :headers, :body

    def initialize(notification)
      @path    = "/3/device/#{notification.token}"
      @headers = build_headers_for notification
      @body    = notification.body
    end

    private

    def build_headers_for(notification)
      h = {}
      h.merge!('apns-id' => notification.apns_id) if notification.apns_id
      h.merge!('apns-expiration' => notification.expiration) if notification.expiration
      h.merge!('apns-priority' => notification.priority) if notification.priority
      h.merge!('apns-push-type' => notification.background_notification? ? 'background' : 'alert' )
      h.merge!('apns-topic' => notification.topic) if notification.topic
      h.merge!('apns-collapse-id' => notification.apns_collapse_id) if notification.apns_collapse_id
      h.merge!('authorization' => notification.authorization_header) if notification.authorization_header
      h.merge! notification.custom_headers if notification.custom_headers
      h
    end
  end
end
