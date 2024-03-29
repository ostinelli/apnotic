# frozen_string_literal: true

require 'securerandom'
require 'json'

module Apnotic
  class AbstractNotification
    attr_reader :token
    attr_accessor :apns_id,
                  :expiration,
                  :priority,
                  :topic,
                  :apns_collapse_id,
                  :authorization,
                  :push_type

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

    def background_notification?
      false
    end

    private

    def to_hash
      raise NotImplementedError, 'implement the to_hash method in a child class'
    end
  end
end
