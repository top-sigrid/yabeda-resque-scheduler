# frozen_string_literal: true

require "test_helper"

module Yabeda
  module Resque
    module Scheduler
      module DelayedJobCounter
        class JobParserIntegrationTest < Minitest::Test
          def setup
            flush_redis
          end

          def teardown
            flush_redis
          end

          # === Native Resque Job Tests ===

          def test_parse_real_native_resque_job
            timestamp = Time.now + 3600
            ::Resque.enqueue_at(timestamp, TestJob, "arg1", "arg2")

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "default", result[:queue], "Should extract queue from real native job"
            assert_equal "TestJob", result[:job_class], "Should extract class from real native job"
          end

          def test_parse_real_native_job_with_custom_queue
            timestamp = Time.now + 3600
            ::Resque.enqueue_at_with_queue("critical", timestamp, TestJob, "arg1")

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "critical", result[:queue], "Should extract overridden queue"
            assert_equal "TestJob", result[:job_class]
          end

          def test_parse_real_native_job_without_args
            timestamp = Time.now + 3600
            ::Resque.enqueue_at(timestamp, AnotherTestJob)

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "high", result[:queue]
            assert_equal "AnotherTestJob", result[:job_class]
          end

          # === ActiveJob Tests ===

          def test_parse_real_active_job
            timestamp = Time.now + 3600
            TestActiveJob.set(wait_until: timestamp).perform_later("arg1", "arg2")

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "active_job_queue", result[:queue], "Should extract queue_name from ActiveJob payload"
            assert_equal "TestActiveJob", result[:job_class], "Should extract job_class from ActiveJob payload"
          end

          def test_parse_real_active_job_without_args
            timestamp = Time.now + 3600
            TestActiveJob.set(wait_until: timestamp).perform_later

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "active_job_queue", result[:queue]
            assert_equal "TestActiveJob", result[:job_class]
          end

          def test_parse_real_active_job_with_queue_override
            timestamp = Time.now + 3600
            TestActiveJob.set(wait_until: timestamp, queue: "critical").perform_later

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "critical", result[:queue], "Should extract overridden queue from ActiveJob"
            assert_equal "TestActiveJob", result[:job_class]
          end

          # === Verify JobParser extracts same data as stored ===

          def test_parse_native_job_extracts_exact_stored_values
            timestamp = Time.now + 3600
            ::Resque.enqueue_at(timestamp, AnotherTestJob, {id: 123})

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal job["queue"], result[:queue], "Extracted queue should match stored queue"
            assert_equal job["class"], result[:job_class], "Extracted class should match stored class"
          end

          def test_parse_active_job_extracts_exact_stored_values
            timestamp = Time.now + 3600
            TestActiveJob.set(wait_until: timestamp).perform_later

            job = fetch_first_delayed_job(timestamp)
            payload = job["args"][0]
            result = JobParser.parse(job)

            assert_equal payload["queue_name"], result[:queue], "Extracted queue should match payload queue_name"
            assert_equal payload["job_class"], result[:job_class], "Extracted class should match payload job_class"
          end
        end
      end
    end
  end
end
