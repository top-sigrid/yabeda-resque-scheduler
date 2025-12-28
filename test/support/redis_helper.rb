# frozen_string_literal: true

module RedisHelper
  # Flushes the entire test Redis database (db 15)
  # Uses the underlying Redis connection to avoid namespace warnings
  def flush_redis
    Resque.redis.redis.flushdb
  end

  # Fetches and decodes the first delayed job at a given timestamp
  def fetch_first_delayed_job(timestamp)
    stored_jobs = Resque.redis.lrange("delayed:#{timestamp.to_i}", 0, -1)
    Resque.decode(stored_jobs.first)
  end

  # Fetches and decodes all delayed jobs at a given timestamp
  def fetch_delayed_jobs(timestamp)
    stored_jobs = Resque.redis.lrange("delayed:#{timestamp.to_i}", 0, -1)
    stored_jobs.map { |job| Resque.decode(job) }
  end
end
