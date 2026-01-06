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

          def test_parses_real_native_resque_job
            timestamp = Time.now + 3600
            schedule_delayed_job(TestJob, timestamp: timestamp, args: ["arg1", "arg2"])

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "default", result[:queue], "Should extract queue from real native job"
            assert_equal "TestJob", result[:job_class], "Should extract class from real native job"
          end

          def test_parses_real_native_job_with_custom_queue
            timestamp = Time.now + 3600
            schedule_delayed_job(TestJob, timestamp: timestamp, queue: "critical", args: ["arg1"])

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "critical", result[:queue], "Should extract overridden queue"
            assert_equal "TestJob", result[:job_class]
          end

          def test_parses_real_native_job_without_args
            timestamp = Time.now + 3600
            schedule_delayed_job(AnotherTestJob, timestamp: timestamp)

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "high", result[:queue]
            assert_equal "AnotherTestJob", result[:job_class]
          end

          # === ActiveJob Tests ===

          def test_parses_real_active_job
            timestamp = Time.now + 3600
            schedule_delayed_active_job(TestActiveJob, timestamp: timestamp, args: ["arg1", "arg2"])

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "active_job_queue", result[:queue], "Should extract queue_name from ActiveJob payload"
            assert_equal "TestActiveJob", result[:job_class], "Should extract job_class from ActiveJob payload"
          end

          def test_parses_real_active_job_with_queue_override
            timestamp = Time.now + 3600
            schedule_delayed_active_job(TestActiveJob, timestamp: timestamp, queue: "critical")

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "critical", result[:queue], "Should extract overridden queue from ActiveJob"
            assert_equal "TestActiveJob", result[:job_class]
          end

          def test_parses_real_active_job_without_args
            timestamp = Time.now + 3600
            schedule_delayed_active_job(TestActiveJob, timestamp: timestamp)

            job = fetch_first_delayed_job(timestamp)
            result = JobParser.parse(job)

            assert_equal "active_job_queue", result[:queue]
            assert_equal "TestActiveJob", result[:job_class]
          end

        end
      end
    end
  end
end
