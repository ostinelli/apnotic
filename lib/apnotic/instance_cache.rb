module Apnotic
  class InstanceCache
    def initialize(instance, method, ttl)
      @instance = instance
      @method   = method
      @ttl      = ttl
    end

    def call
      if @cached_value && !expired?
        @cached_value
      else
        new_value
      end
    end

    private

    def expired?
      Time.now - @cached_at >= @ttl
    end

    def new_value
      @cached_at = Time.now
      @cached_value = @instance.send(@method)
    end
  end
end