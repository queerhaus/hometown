# frozen_string_literal: true

class RateLimiter
  include Redisable

  FAMILIES = {
    follows: {
      limit: 400,
      period: 24.hours.freeze,
    }.freeze,

    statuses: {
      limit: 300,
      period: 3.hours.freeze,
    }.freeze,

    invites: {
      limit: 1,
      period: 1.week.freeze,
    }.freeze,

    reports: {
      limit: 400,
      period: 24.hours.freeze,
    }.freeze,
  }.freeze

  def initialize(by, options = {})
    @by     = by
    @family = options[:family]
    @limit  = FAMILIES[@family][:limit]
    @period = FAMILIES[@family][:period].to_i
    @generated_via = options[:generated_via]
  end

  def record!
    count = redis.get(key)
    cooldown = (@period - (last_epoch_time % @period) + 1).to_i
    
    if count.nil?
      redis.set(key, 0)
      redis.expire(key, cooldown)
    end

    raise Mastodon::RateLimitExceededError.new(
      (Time.now + cooldown.seconds).to_s, @generated_via
    ) if count.present? && count.to_i >= @limit

    redis.incr(key)
  end

  def rollback!
    redis.decr(key)
  end

  def to_headers(now = Time.now.utc)
    {
      'X-RateLimit-Limit' => @limit.to_s,
      'X-RateLimit-Remaining' => (@limit - (redis.get(key) || 0).to_i).to_s,
      'X-RateLimit-Reset' => (now + (@period - now.to_i % @period)).iso8601(6),
    }
  end

  private

  def key
    @key ||= "rate_limit:#{@by.id}:#{@family}:#{(last_epoch_time / @period).to_i}"
  end

  def last_epoch_time
    @last_epoch_time ||= Time.now.to_i
  end
end
