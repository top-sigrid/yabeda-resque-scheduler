# frozen_string_literal: true

module RedisHelper
  # Flushes the entire test Redis database (db 15)
  def flush_redis
    Resque.redis.redis.flushdb
  end

  # Fetches and decodes the first delayed job at a given timestamp
  def fetch_first_delayed_job(timestamp)
    stored_jobs = Resque.redis.lrange("delayed:#{timestamp.to_i}", 0, -1)
    Resque.decode(stored_jobs.first)
  end
end
