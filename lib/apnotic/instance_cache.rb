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
      now - @cached_at >= @ttl
    end

    def new_value
      @cached_at = now
      @cached_value = @instance.send(@method)
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end