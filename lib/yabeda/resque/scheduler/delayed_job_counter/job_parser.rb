# frozen_string_literal: true

module Yabeda
  module Resque
    module Scheduler
      module DelayedJobCounter
        # Parses delayed job payloads to extract queue and job_class.
        # Supports both native Resque jobs and ActiveJob (JobWrapper) jobs.
        #
        # Native Resque job format:
        #   { "class" => "MyJob", "queue" => "default", "args" => [...] }
        #
        # ActiveJob (JobWrapper) format:
        #   { "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
        #     "queue" => "default",
        #     "args" => [{ "job_class" => "MyActiveJob", "queue_name" => "default", ... }] }
        module JobParser
          ACTIVE_JOB_WRAPPER_CLASS = "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"

          class << self
            # Extracts queue and job_class from a decoded job hash.
            # Returns a hash with :queue and :job_class keys, or nil values if extraction fails.
            #
            # @param job [Hash] Decoded job payload from Redis
            # @return [Hash] { queue: String|nil, job_class: String|nil }
            def parse(job)
              return {queue: nil, job_class: nil} unless job.is_a?(Hash)

              if active_job_wrapper?(job)
                parse_active_job(job)
              else
                parse_native_job(job)
              end
            end

            # Extracts only the queue from a job.
            # @param job [Hash] Decoded job payload from Redis
            # @return [String, nil] Queue name or nil
            def extract_queue(job)
              parse(job)[:queue]
            end

            # Extracts only the job_class from a job.
            # @param job [Hash] Decoded job payload from Redis
            # @return [String, nil] Job class name or nil
            def extract_job_class(job)
              parse(job)[:job_class]
            end

            private

            def active_job_wrapper?(job)
              job["class"] == ACTIVE_JOB_WRAPPER_CLASS
            end

            def parse_native_job(job)
              {
                queue: job["queue"]&.to_s,
                job_class: job["class"]&.to_s
              }
            end

            def parse_active_job(job)
              payload = job.dig("args", 0)
              return {queue: nil, job_class: nil} unless payload.is_a?(Hash)

              {
                queue: payload["queue_name"]&.to_s || job["queue"]&.to_s,
                job_class: payload["job_class"]&.to_s
              }
            end
          end
        end
      end
    end
  end
end
