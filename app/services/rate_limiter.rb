# frozen_string_literal: true

require "monitor"

class RateLimiter
  class Bucket
    attr_accessor :tokens, :last_refill

    def initialize(capacity, refill_rate)
      @capacity = capacity.to_f
      @tokens = capacity.to_f
      @refill_rate = refill_rate.to_f # tokens per second
      @last_refill = Time.now.to_f
    end

    def take(count = 1)
      now = Time.now.to_f
      elapsed = now - @last_refill
      @tokens = [@capacity, @tokens + (elapsed * @refill_rate)].min
      @last_refill = now

      if @tokens >= count
        @tokens -= count
        [true, 0, @tokens.floor]
      else
        seconds_needed = ((count - @tokens) / @refill_rate).ceil
        [false, [seconds_needed, 1].max, 0]
      end
    end

    def stale?(max_idle_seconds = 300)
      (Time.now.to_f - @last_refill) > max_idle_seconds
    end
  end

  @buckets = {}
  @lock = Monitor.new
  @last_cleanup = Time.now.to_f

  class << self
    # check(key, limit: 100, window: 60)
    # returns [allowed (boolean), retry_after (integer seconds), remaining (integer)]
    def check(key, limit: 100, window: 60)
      refill_rate = limit.to_f / window.to_f

      @lock.synchronize do
        maybe_cleanup

        bucket = (@buckets[key] ||= Bucket.new(limit, refill_rate))
        bucket.take(1)
      end
    end

    def reset!(key = nil)
      @lock.synchronize do
        if key
          @buckets.delete(key)
        else
          @buckets.clear
        end
      end
    end

    def stats
      @lock.synchronize do
        {
          tracked_keys: @buckets.size,
          last_cleanup_at: Time.at(@last_cleanup).utc.iso8601
        }
      end
    end

    private

    def maybe_cleanup
      now = Time.now.to_f
      return if (now - @last_cleanup) < 60

      @buckets.delete_if { |_, bucket| bucket.stale?(300) }
      @last_cleanup = now
    end
  end
end
