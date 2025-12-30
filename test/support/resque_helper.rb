# frozen_string_literal: true

module ResqueHelper
  # Schedules a Resque job via resque-scheduler.
  # For ActiveJobs use schedule_delayed_active_job.
  #
  # @param job_class [Class] Job class (must have @queue defined)
  # @param timestamp [Time, Integer] When to execute the job
  # @param queue [String, nil] Optional queue override ()
  # @param args [Array] Job arguments
  def schedule_delayed_job(job_class, timestamp:, queue: nil, args: [])
    if queue
      Resque.enqueue_at_with_queue(queue, timestamp, job_class, *args)
    else
      Resque.enqueue_at(timestamp, job_class, *args)
    end
  end

  # Schedules an ActiveJob to run at a specific time.
  #
  # @param job_class [Class] ActiveJob class
  # @param timestamp [Time, Integer] When to execute the job
  # @param queue [String, nil] Optional queue override
  # @param args [Array] Job arguments
  def schedule_delayed_active_job(job_class, timestamp:, queue: nil, args: [])
    options = {wait_until: timestamp}
    options[:queue] = queue if queue
    job_class.set(options).perform_later(*args)
  end

  # Adds a malformed job (missing queue) directly to Redis for testing error handling.
  #
  # @param timestamp [Time, Integer] When to execute the job
  def add_malformed_delayed_job(timestamp: Time.now + 3600)
    timestamp = timestamp.to_i
    job_data = Resque.encode({"class" => "MalformedJob", "args" => []})
    Resque.redis.rpush("delayed:#{timestamp}", job_data)
    Resque.redis.zadd("delayed_queue_schedule", timestamp, timestamp)
  end
end
