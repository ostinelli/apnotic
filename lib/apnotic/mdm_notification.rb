require 'apnotic/abstract_notification'

module Apnotic

  class MdmNotification < AbstractNotification
    attr_reader :push_magic

    def initialize(push_magic:, token:)
      super(token)
      @push_magic = push_magic
    end

    private

    def to_hash
      { mdm: push_magic }
    end
  end
end
