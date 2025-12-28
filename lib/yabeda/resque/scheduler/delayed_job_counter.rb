# frozen_string_literal: true

require_relative "delayed_job_counter/job_parser"

module Yabeda
  module Resque
    module Scheduler
      # Counts delayed jobs in resque-scheduler by queue and job_class.
      # Designed for use with Yabeda metrics collectors.
      #
      # Usage:
      #   result = DelayedJobCounter.count_delayed_jobs
      #   result.by_queue        # => { "default" => 5, "mailers" => 3 }
      #   result.by_job_class    # => { "MyJob" => 5, "WelcomeMailer" => 3 }
      #   result.by_queue_and_class # => { ["default", "MyJob"] => 5, ... }
      module DelayedJobCounter
        # Result object containing all three count dimensions from a single scan
        Result = Struct.new(:by_queue, :by_job_class, :by_queue_and_class, keyword_init: true) do
          def empty?
            by_queue.empty? && by_job_class.empty? && by_queue_and_class.empty?
          end
        end

        EMPTY_RESULT = Result.new(
          by_queue: {}.freeze,
          by_job_class: {}.freeze,
          by_queue_and_class: {}.freeze
        ).freeze

        class << self
          # Counts all delayed jobs, aggregating by queue, job_class, and both combined.
          # Performs a single scan of Redis and accumulates all three dimensions in one pass.
          #
          # @return [Result] Struct with by_queue, by_job_class, and by_queue_and_class hashes
          def count_delayed_jobs
            timestamps = ::Resque.redis.zrange("delayed_queue_schedule", 0, -1)
            return EMPTY_RESULT if timestamps.empty?

            jobs_by_timestamp = ::Resque.redis.pipelined do |pipeline|
              timestamps.each do |timestamp|
                pipeline.lrange("delayed:#{timestamp}", 0, -1)
              end
            end

            by_queue = Hash.new(0)
            by_job_class = Hash.new(0)
            by_queue_and_class = Hash.new(0)

            jobs_by_timestamp.each do |jobs|
              jobs.each do |job_json|
                job = ::Resque.decode(job_json)
                parsed = JobParser.parse(job)
                queue = parsed[:queue]
                job_class = parsed[:job_class]

                next unless queue && job_class

                by_queue[queue] += 1
                by_job_class[job_class] += 1
                by_queue_and_class[[queue, job_class]] += 1
              end
            end

            Result.new(
              by_queue: by_queue,
              by_job_class: by_job_class,
              by_queue_and_class: by_queue_and_class
            )
          end
        end
      end
    end
  end
end
