# frozen_string_literal: true

require "test_helper"

module Yabeda
  module Resque
    module Scheduler
      class DelayedJobCounterTest < Minitest::Test
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
          schedule_delayed_job(TestJob, timestamp: Time.now + 3600)

          result = DelayedJobCounter.count_delayed_jobs

          assert_kind_of DelayedJobCounter::Result, result
          assert_respond_to result, :by_queue
          assert_respond_to result, :by_job_class
          assert_respond_to result, :by_queue_and_class
        end

        def test_count_delayed_jobs_counts_single_native_job
          schedule_delayed_job(TestJob, timestamp: Time.now + 3600)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1}, result.by_queue)
          assert_equal({"TestJob" => 1}, result.by_job_class)
          assert_equal({["default", "TestJob"] => 1}, result.by_queue_and_class)
        end

        def test_count_delayed_jobs_counts_single_active_job
          timestamp = Time.now + 3600
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"active_job_queue" => 1}, result.by_queue)
          assert_equal({"TestActiveJob" => 1}, result.by_job_class)
          assert_equal({["active_job_queue", "TestActiveJob"] => 1}, result.by_queue_and_class)
        end

        def test_count_delayed_jobs_counts_multiple_native_jobs_same_queue
          timestamp = Time.now + 3600
          schedule_delayed_job(TestJob, timestamp: timestamp)
          schedule_delayed_job(TestJob, timestamp: timestamp)
          schedule_delayed_job(TestJob, timestamp: timestamp + 100)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 3}, result.by_queue)
          assert_equal({"TestJob" => 3}, result.by_job_class)
          assert_equal({["default", "TestJob"] => 3}, result.by_queue_and_class)
        end

        def test_count_delayed_jobs_groups_by_all_dimensions
          timestamp = Time.now + 3600
          schedule_delayed_job(TestJob, timestamp: timestamp)
          schedule_delayed_job(AnotherTestJob, timestamp: timestamp)
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp)
          schedule_delayed_job(TestJob, timestamp: timestamp + 100)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 2, "high" => 1, "active_job_queue" => 1}, result.by_queue)
          assert_equal({"TestJob" => 2, "AnotherTestJob" => 1, "TestActiveJob" => 1}, result.by_job_class)
          assert_equal 3, result.by_queue_and_class.keys.size
          assert_equal 2, result.by_queue_and_class[["default", "TestJob"]]
          assert_equal 1, result.by_queue_and_class[["high", "AnotherTestJob"]]
          assert_equal 1, result.by_queue_and_class[["active_job_queue", "TestActiveJob"]]
        end

        def test_count_delayed_jobs_aggregates_same_job_in_different_queues
          timestamp = Time.now + 3600
          schedule_delayed_job(TestJob, timestamp: timestamp)
          schedule_delayed_job(TestJob, timestamp: timestamp, queue: "critical")
          schedule_delayed_job(TestJob, timestamp: timestamp, queue: "critical")

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1, "critical" => 2}, result.by_queue)
          assert_equal({"TestJob" => 3}, result.by_job_class, "Should aggregate TestJob across all queues")
          assert_equal 2, result.by_queue_and_class.keys.size
          assert_equal 1, result.by_queue_and_class[["default", "TestJob"]]
          assert_equal 2, result.by_queue_and_class[["critical", "TestJob"]]
        end

        def test_count_delayed_jobs_aggregates_same_active_job_in_different_queues
          timestamp = Time.now + 3600
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp)
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp, queue: "critical")
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp, queue: "critical")

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"active_job_queue" => 1, "critical" => 2}, result.by_queue)
          assert_equal({"TestActiveJob" => 3}, result.by_job_class, "Should aggregate TestActiveJob across all queues")
          assert_equal 2, result.by_queue_and_class.keys.size
          assert_equal 1, result.by_queue_and_class[["active_job_queue", "TestActiveJob"]]
          assert_equal 2, result.by_queue_and_class[["critical", "TestActiveJob"]]
        end

        def test_count_delayed_jobs_counts_mixed_native_and_active_jobs
          timestamp = Time.now + 3600
          schedule_delayed_job(TestJob, timestamp: timestamp)
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp)
          schedule_delayed_active_job(AnotherActiveJob, timestamp: timestamp)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1, "active_job_queue" => 1, "another_queue" => 1}, result.by_queue)
          assert_equal({"TestJob" => 1, "TestActiveJob" => 1, "AnotherActiveJob" => 1}, result.by_job_class)
          assert_equal 3, result.by_queue_and_class.keys.size
        end

        def test_count_delayed_jobs_aggregates_different_jobs_in_same_queue
          timestamp = Time.now + 3600
          schedule_delayed_job(TestJob, timestamp: timestamp)
          schedule_delayed_job(AnotherTestJob, timestamp: timestamp, queue: "default")
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp, queue: "default")

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 3}, result.by_queue, "Should aggregate all jobs in default queue")
          assert_equal({"TestJob" => 1, "AnotherTestJob" => 1, "TestActiveJob" => 1}, result.by_job_class)
          assert_equal 3, result.by_queue_and_class.keys.size
        end

        def test_count_delayed_jobs_across_multiple_timestamps
          now = Time.now
          schedule_delayed_job(TestJob, timestamp: now + 100)
          schedule_delayed_job(TestJob, timestamp: now + 200)
          schedule_delayed_job(TestJob, timestamp: now + 300)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 3}, result.by_queue)
          assert_equal({"TestJob" => 3}, result.by_job_class)
          assert_equal({["default", "TestJob"] => 3}, result.by_queue_and_class)
        end

        def test_count_delayed_jobs_with_args
          schedule_delayed_job(TestJob, timestamp: Time.now + 3600, args: ["arg1", {id: 123}])

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1}, result.by_queue)
          assert_equal({"TestJob" => 1}, result.by_job_class)
        end

        # === Malformed job handling tests ===

        def test_count_delayed_jobs_skips_malformed_jobs
          timestamp = Time.now + 3600
          add_malformed_delayed_job(timestamp: timestamp)
          schedule_delayed_job(TestJob, timestamp: timestamp)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1}, result.by_queue, "Should only count valid jobs")
          assert_equal({"TestJob" => 1}, result.by_job_class, "Should only count valid jobs")
        end

        def test_count_delayed_jobs_handles_only_malformed_jobs
          add_malformed_delayed_job

          result = DelayedJobCounter.count_delayed_jobs

          assert result.empty?, "Result should be empty when only malformed jobs exist"
        end
      end
    end
  end
end
