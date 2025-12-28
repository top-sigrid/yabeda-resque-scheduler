# frozen_string_literal: true

module ResqueHelper
  # Schedules a job via resque-scheduler (triggers hooks).
  # Use this when you want to test with the real resque-scheduler behavior.
  #
  # @param job_class [Class] Job class
  # @param run_at [Time, Integer] When to execute the job
  # @param args [Array] Job arguments
  def schedule_delayed_job(job_class, run_at: Time.now + 3600, args: [])
    Resque.enqueue_at(run_at, job_class, *args)
  end

  # Adds a delayed job directly to Redis, bypassing resque-scheduler hooks.
  # Use this for tests that need to create jobs without triggering any side effects.
  #
  # @param queue [String] Queue name
  # @param job_class [String] Job class name (defaults to "TestJob")
  # @param timestamp [Time, Integer] When to execute the job
  # @param args [Array] Job arguments
  def add_delayed_job_without_hooks(queue:, job_class: "TestJob", timestamp: Time.now + 3600, args: [])
    timestamp = timestamp.to_i
    job_data = Resque.encode({"class" => job_class, "args" => args, "queue" => queue})
    Resque.redis.rpush("delayed:#{timestamp}", job_data)
    Resque.redis.zadd("delayed_queue_schedule", timestamp, timestamp)
  end

  # Adds a malformed job (missing queue) directly to Redis.
  # Use this for testing graceful handling of invalid job data.
  #
  # @param job_class [String] Job class name
  # @param timestamp [Time, Integer] When to execute the job
  def add_malformed_job_without_queue(job_class: "MalformedJob", timestamp: Time.now + 3600)
    timestamp = timestamp.to_i
    job_data = Resque.encode({"class" => job_class, "args" => []})
    Resque.redis.rpush("delayed:#{timestamp}", job_data)
    Resque.redis.zadd("delayed_queue_schedule", timestamp, timestamp)
  end

  # Schedules a native Resque job to be executed at a specific time.
  # Directly writes to Redis in the same format as Resque.enqueue_at.
  #
  # @param klass [Class, String] Job class or class name
  # @param queue [String] Queue name
  # @param timestamp [Time, Integer] When to execute the job
  # @param args [Array] Job arguments
  def schedule_native_job(klass, queue:, timestamp:, args: [])
    timestamp = timestamp.to_i
    job = {
      "class" => klass.to_s,
      "queue" => queue.to_s,
      "args" => args
    }
    encoded_job = Resque.encode(job)

    Resque.redis.rpush("delayed:#{timestamp}", encoded_job)
    Resque.redis.zadd("delayed_queue_schedule", timestamp, timestamp)
  end

  # Schedules an ActiveJob-style job (JobWrapper) to be executed at a specific time.
  # Directly writes to Redis in the same format as ActiveJob with Resque adapter.
  #
  # @param job_class [Class, String] The ActiveJob class name
  # @param queue [String] Queue name
  # @param timestamp [Time, Integer] When to execute the job
  # @param job_id [String] Optional job UUID
  # @param args [Array] Job arguments
  def schedule_active_job(job_class, queue:, timestamp:, job_id: nil, args: [])
    timestamp = timestamp.to_i
    job_id ||= SecureRandom.uuid

    payload = {
      "job_class" => job_class.to_s,
      "job_id" => job_id,
      "queue_name" => queue.to_s,
      "arguments" => args
    }

    job = {
      "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
      "queue" => queue.to_s,
      "args" => [payload]
    }
    encoded_job = Resque.encode(job)

    Resque.redis.rpush("delayed:#{timestamp}", encoded_job)
    Resque.redis.zadd("delayed_queue_schedule", timestamp, timestamp)
  end

  # Schedules multiple jobs at once for testing bulk operations
  #
  # @param jobs [Array<Hash>] Array of job specs with :type, :class, :queue, :timestamp
  def schedule_jobs(jobs)
    jobs.each do |spec|
      case spec[:type]
      when :native
        schedule_native_job(spec[:class], queue: spec[:queue], timestamp: spec[:timestamp], args: spec[:args] || [])
      when :active_job
        schedule_active_job(spec[:class], queue: spec[:queue], timestamp: spec[:timestamp], args: spec[:args] || [])
      else
        raise ArgumentError, "Unknown job type: #{spec[:type]}"
      end
    end
  end
end
