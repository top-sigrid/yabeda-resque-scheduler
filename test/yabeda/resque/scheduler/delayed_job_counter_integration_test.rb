# frozen_string_literal: true

require "test_helper"

module Yabeda
  module Resque
    module Scheduler
      class DelayedJobCounterIntegrationTest < Minitest::Test
        def setup
          flush_redis
        end

        def teardown
          flush_redis
        end

        # === Native Resque Job Integration Tests ===

        def test_real_enqueue_at_stores_job_with_expected_structure
          timestamp = Time.now + 3600
          ::Resque.enqueue_at(timestamp, TestJob, "arg1", "arg2")

          stored_jobs = ::Resque.redis.lrange("delayed:#{timestamp.to_i}", 0, -1)
          assert_equal 1, stored_jobs.size, "Should have one job stored"

          job = ::Resque.decode(stored_jobs.first)
          assert_equal "TestJob", job["class"], "Job class should be TestJob"
          assert_equal "default", job["queue"], "Queue should match @queue from TestJob"
          assert_equal ["arg1", "arg2"], job["args"], "Args should be preserved"
        end

        def test_real_enqueue_at_with_queue_overrides_default_queue
          timestamp = Time.now + 3600
          ::Resque.enqueue_at_with_queue("critical", timestamp, TestJob, "arg1")

          stored_jobs = ::Resque.redis.lrange("delayed:#{timestamp.to_i}", 0, -1)
          job = ::Resque.decode(stored_jobs.first)

          assert_equal "TestJob", job["class"]
          assert_equal "critical", job["queue"], "Queue should be overridden to critical"
        end

        def test_count_delayed_jobs_works_with_real_enqueue_at
          timestamp = Time.now + 3600
          ::Resque.enqueue_at(timestamp, TestJob)
          ::Resque.enqueue_at(timestamp, AnotherTestJob)
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp + 100)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"default" => 1, "high" => 1, "active_job_queue" => 1}, result.by_queue)
          assert_equal({"TestJob" => 1, "AnotherTestJob" => 1, "TestActiveJob" => 1}, result.by_job_class)
        end

        def test_schedule_delayed_job_helper_matches_real_enqueue_at
          timestamp = Time.now + 3600

          schedule_delayed_job(TestJob, timestamp: timestamp, args: ["arg1"])
          ::Resque.enqueue_at(timestamp + 1, TestJob, "arg2")

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal 2, result.by_job_class["TestJob"], "Both jobs should be counted"
        end

        def test_inspect_real_native_job_structure
          timestamp = Time.now + 3600
          ::Resque.enqueue_at(timestamp, TestJob, {user_id: 123})

          stored_jobs = ::Resque.redis.lrange("delayed:#{timestamp.to_i}", 0, -1)
          job = ::Resque.decode(stored_jobs.first)

          assert_kind_of Hash, job
          assert job.key?("class"), "Job should have 'class' key (string, not symbol)"
          assert job.key?("queue"), "Job should have 'queue' key"
          assert job.key?("args"), "Job should have 'args' key"
          refute job.key?(:class), "Keys should be strings after JSON decode, not symbols"
        end

        # === ActiveJob Integration Tests ===

        def test_real_active_job_enqueue_at_stores_job_with_expected_structure
          timestamp = Time.now + 3600
          TestActiveJob.set(wait_until: timestamp).perform_later("arg1", "arg2")

          stored_jobs = ::Resque.redis.lrange("delayed:#{timestamp.to_i}", 0, -1)
          assert_equal 1, stored_jobs.size, "Should have one job stored"

          job = ::Resque.decode(stored_jobs.first)

          assert_equal "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper", job["class"],
            "Job class should be JobWrapper"
          assert_equal "active_job_queue", job["queue"],
            "Queue should match queue_as from TestActiveJob"
          assert_kind_of Array, job["args"], "Args should be an array"
          assert_equal 1, job["args"].size, "Args should contain one element (the serialized job)"

          payload = job["args"][0]
          assert_kind_of Hash, payload, "First arg should be a hash (serialized ActiveJob)"
          assert_equal "TestActiveJob", payload["job_class"], "Payload should contain job_class"
          assert_equal "active_job_queue", payload["queue_name"], "Payload should contain queue_name"
          assert payload.key?("job_id"), "Payload should contain job_id"
          assert_equal ["arg1", "arg2"], payload["arguments"], "Payload should contain arguments"
        end

        def test_inspect_real_active_job_structure
          timestamp = Time.now + 3600
          TestActiveJob.set(wait_until: timestamp).perform_later

          stored_jobs = ::Resque.redis.lrange("delayed:#{timestamp.to_i}", 0, -1)
          job = ::Resque.decode(stored_jobs.first)
          payload = job["args"][0]

          expected_keys = %w[job_class job_id queue_name arguments executions exception_executions locale timezone enqueued_at scheduled_at]
          expected_keys.each do |key|
            assert payload.key?(key), "ActiveJob payload should have '#{key}' key"
          end
        end

        def test_count_delayed_jobs_works_with_real_active_job
          timestamp = Time.now + 3600
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp)
          schedule_delayed_active_job(AnotherActiveJob, timestamp: timestamp)
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp + 100)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal({"active_job_queue" => 2, "another_queue" => 1}, result.by_queue)
          assert_equal({"TestActiveJob" => 2, "AnotherActiveJob" => 1}, result.by_job_class)
        end

        def test_count_delayed_jobs_with_multiple_active_jobs
          timestamp = Time.now + 3600
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp)
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp + 1)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal 2, result.by_job_class["TestActiveJob"], "Both jobs should be counted"
          assert_equal 2, result.by_queue["active_job_queue"], "Both jobs should be in same queue"
        end

        # === Mixed Native + ActiveJob Tests ===

        def test_count_delayed_jobs_with_mixed_real_native_and_active_jobs
          timestamp = Time.now + 3600
          schedule_delayed_job(TestJob, timestamp: timestamp)
          schedule_delayed_job(AnotherTestJob, timestamp: timestamp)
          schedule_delayed_active_job(TestActiveJob, timestamp: timestamp)
          schedule_delayed_active_job(AnotherActiveJob, timestamp: timestamp)

          result = DelayedJobCounter.count_delayed_jobs

          assert_equal 4, result.by_queue.values.sum, "Should count all 4 jobs"
          assert_equal 4, result.by_job_class.values.sum, "Should count all 4 job classes"

          assert_equal 1, result.by_queue["default"]
          assert_equal 1, result.by_queue["high"]
          assert_equal 1, result.by_queue["active_job_queue"]
          assert_equal 1, result.by_queue["another_queue"]
        end
      end
    end
  end
end
