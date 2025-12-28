# frozen_string_literal: true

require "test_helper"

module Yabeda
  module Resque
    module Scheduler
      class DelayedJobCounterTest < Minitest::Test
        include RedisHelper
        include ResqueHelper

        def setup
          flush_redis
        end

        def teardown
          flush_redis
        end

        def test_count_delayed_jobs_returns_empty_result_when_no_jobs
          result = DelayedJobCounter.count_delayed_jobs

          assert result.empty?, "Result should be empty when no jobs scheduled"
          assert_equal({}, result.by_queue)
          assert_equal({}, result.by_job_class)
          assert_equal({}, result.by_queue_and_class)
        end

        def test_count_delayed_jobs_returns_result_struct
          schedule_native_job(TestJob, queue: "default", timestamp: Time.now.to_i + 3600)

          result = DelayedJobCounter.count_delayed_jobs

          assert_kind_of DelayedJobCounter::Result, result
          assert_respond_to result, :by_queue
          assert_respond_to result, :by_job_class
          assert_respond_to result, :by_queue_and_class
        end

        def test_count_delayed_jobs_counts_single_native_job
          schedule_native_job(TestJob, queue: "default", timestamp: Time.now.to_i + 3600)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1}, result.by_queue)
          assert_equal({"TestJob" => 1}, result.by_job_class)
          assert_equal({["default", "TestJob"] => 1}, result.by_queue_and_class)
        end

        def test_count_delayed_jobs_counts_multiple_native_jobs_same_queue
          timestamp = Time.now.to_i + 3600
          schedule_native_job(TestJob, queue: "default", timestamp: timestamp)
          schedule_native_job(TestJob, queue: "default", timestamp: timestamp)
          schedule_native_job(TestJob, queue: "default", timestamp: timestamp + 100)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 3}, result.by_queue)
          assert_equal({"TestJob" => 3}, result.by_job_class)
          assert_equal({["default", "TestJob"] => 3}, result.by_queue_and_class)
        end

        def test_count_delayed_jobs_groups_by_all_dimensions
          timestamp = Time.now.to_i + 3600
          schedule_native_job(TestJob, queue: "default", timestamp: timestamp)
          schedule_native_job(AnotherTestJob, queue: "high", timestamp: timestamp)
          schedule_native_job(MailerJob, queue: "mailers", timestamp: timestamp)
          schedule_native_job(TestJob, queue: "default", timestamp: timestamp + 100)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 2, "high" => 1, "mailers" => 1}, result.by_queue)
          assert_equal({"TestJob" => 2, "AnotherTestJob" => 1, "MailerJob" => 1}, result.by_job_class)
          assert_equal 3, result.by_queue_and_class.keys.size
          assert_equal 2, result.by_queue_and_class[["default", "TestJob"]]
          assert_equal 1, result.by_queue_and_class[["high", "AnotherTestJob"]]
          assert_equal 1, result.by_queue_and_class[["mailers", "MailerJob"]]
        end

        def test_count_delayed_jobs_counts_active_jobs
          schedule_active_job("WelcomeMailer", queue: "mailers", timestamp: Time.now.to_i + 3600)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"mailers" => 1}, result.by_queue)
          assert_equal({"WelcomeMailer" => 1}, result.by_job_class)
          assert_equal({["mailers", "WelcomeMailer"] => 1}, result.by_queue_and_class)
        end

        def test_count_delayed_jobs_counts_mixed_native_and_active_jobs
          timestamp = Time.now.to_i + 3600
          schedule_native_job(TestJob, queue: "default", timestamp: timestamp)
          schedule_active_job("ProcessOrderJob", queue: "orders", timestamp: timestamp)
          schedule_active_job("WelcomeMailer", queue: "mailers", timestamp: timestamp)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1, "orders" => 1, "mailers" => 1}, result.by_queue)
          assert_equal({"TestJob" => 1, "ProcessOrderJob" => 1, "WelcomeMailer" => 1}, result.by_job_class)
          assert_equal 3, result.by_queue_and_class.keys.size
        end

        def test_count_delayed_jobs_aggregates_same_job_in_different_queues
          timestamp = Time.now.to_i + 3600
          schedule_native_job(TestJob, queue: "default", timestamp: timestamp)
          schedule_native_job(TestJob, queue: "critical", timestamp: timestamp)
          schedule_native_job(TestJob, queue: "critical", timestamp: timestamp)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1, "critical" => 2}, result.by_queue)
          assert_equal({"TestJob" => 3}, result.by_job_class, "Should aggregate TestJob across all queues")
          assert_equal 2, result.by_queue_and_class.keys.size
          assert_equal 1, result.by_queue_and_class[["default", "TestJob"]]
          assert_equal 2, result.by_queue_and_class[["critical", "TestJob"]]
        end

        def test_count_delayed_jobs_aggregates_different_jobs_in_same_queue
          timestamp = Time.now.to_i + 3600
          schedule_native_job(TestJob, queue: "default", timestamp: timestamp)
          schedule_native_job(AnotherTestJob, queue: "default", timestamp: timestamp)
          schedule_native_job(MailerJob, queue: "default", timestamp: timestamp)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 3}, result.by_queue, "Should aggregate all jobs in default queue")
          assert_equal({"TestJob" => 1, "AnotherTestJob" => 1, "MailerJob" => 1}, result.by_job_class)
          assert_equal 3, result.by_queue_and_class.keys.size
        end

        def test_count_delayed_jobs_across_multiple_timestamps
          now = Time.now.to_i
          schedule_native_job(TestJob, queue: "default", timestamp: now + 100)
          schedule_native_job(TestJob, queue: "default", timestamp: now + 200)
          schedule_native_job(TestJob, queue: "default", timestamp: now + 300)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 3}, result.by_queue)
          assert_equal({"TestJob" => 3}, result.by_job_class)
          assert_equal({["default", "TestJob"] => 3}, result.by_queue_and_class)
        end

        def test_count_delayed_jobs_using_schedule_jobs_helper
          timestamp = Time.now.to_i + 3600
          schedule_jobs([
            {type: :native, class: TestJob, queue: "default", timestamp: timestamp},
            {type: :native, class: AnotherTestJob, queue: "high", timestamp: timestamp},
            {type: :active_job, class: "SendNotificationJob", queue: "notifications", timestamp: timestamp}
          ])

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1, "high" => 1, "notifications" => 1}, result.by_queue)
          assert_equal({"TestJob" => 1, "AnotherTestJob" => 1, "SendNotificationJob" => 1}, result.by_job_class)
          assert_equal 3, result.by_queue_and_class.keys.size
        end

        def test_result_empty_returns_false_when_jobs_exist
          schedule_native_job(TestJob, queue: "default", timestamp: Time.now.to_i + 3600)

          result = DelayedJobCounter.count_delayed_jobs

          refute result.empty?, "Result should not be empty when jobs are scheduled"
        end

        # === Real resque-scheduler path tests ===

        def test_count_delayed_jobs_via_resque_scheduler_enqueue_at
          schedule_delayed_job(TestJob, run_at: Time.now + 3600)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1}, result.by_queue)
          assert_equal({"TestJob" => 1}, result.by_job_class)
        end

        def test_count_delayed_jobs_via_resque_scheduler_with_args
          schedule_delayed_job(TestJob, run_at: Time.now + 3600, args: ["arg1", {id: 123}])

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1}, result.by_queue)
          assert_equal({"TestJob" => 1}, result.by_job_class)
        end

        # === Malformed job handling tests ===

        def test_count_delayed_jobs_skips_malformed_jobs_without_queue
          timestamp = Time.now + 3600
          add_malformed_job_without_queue(job_class: "BrokenJob", timestamp: timestamp)
          schedule_native_job(TestJob, queue: "default", timestamp: timestamp)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1}, result.by_queue, "Should only count valid jobs")
          assert_equal({"TestJob" => 1}, result.by_job_class, "Should only count valid jobs")
        end

        def test_count_delayed_jobs_handles_only_malformed_jobs
          add_malformed_job_without_queue(job_class: "BrokenJob", timestamp: Time.now + 3600)

          result = DelayedJobCounter.count_delayed_jobs

          assert result.empty?, "Result should be empty when only malformed jobs exist"
        end

        def test_count_delayed_jobs_handles_jobs_added_without_hooks
          add_delayed_job_without_hooks(queue: "low", job_class: "ManualJob", timestamp: Time.now + 3600)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"low" => 1}, result.by_queue)
          assert_equal({"ManualJob" => 1}, result.by_job_class)
        end
      end
    end
  end
end
