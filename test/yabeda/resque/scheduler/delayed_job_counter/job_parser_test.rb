# frozen_string_literal: true

require "test_helper"

module Yabeda
  module Resque
    module Scheduler
      module DelayedJobCounter
        class JobParserTest < Minitest::Test
          def test_parse_native_job_extracts_queue_and_class
            job = {
              "class" => "TestJob",
              "queue" => "default",
              "args" => ["arg1", "arg2"]
            }

            result = JobParser.parse(job)

            assert_equal "default", result[:queue]
            assert_equal "TestJob", result[:job_class]
          end

          def test_parse_active_job_extracts_queue_and_class_from_payload
            job = {
              "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
              "queue" => "default",
              "args" => [{
                "job_class" => "WelcomeMailer",
                "job_id" => "abc-123",
                "queue_name" => "mailers",
                "arguments" => []
              }]
            }

            result = JobParser.parse(job)

            assert_equal "mailers", result[:queue], "Should use queue_name from ActiveJob payload"
            assert_equal "WelcomeMailer", result[:job_class]
          end

          def test_parse_active_job_falls_back_to_outer_queue_when_queue_name_missing
            job = {
              "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
              "queue" => "fallback_queue",
              "args" => [{
                "job_class" => "SomeJob",
                "job_id" => "abc-123",
                "arguments" => []
              }]
            }

            result = JobParser.parse(job)

            assert_equal "fallback_queue", result[:queue]
            assert_equal "SomeJob", result[:job_class]
          end

          def test_parse_returns_nil_values_for_non_hash_input
            result = JobParser.parse("not a hash")

            assert_nil result[:queue]
            assert_nil result[:job_class]
          end

          def test_parse_returns_nil_values_for_nil_input
            result = JobParser.parse(nil)

            assert_nil result[:queue]
            assert_nil result[:job_class]
          end

          def test_parse_returns_nil_values_for_empty_hash
            result = JobParser.parse({})

            assert_nil result[:queue]
            assert_nil result[:job_class]
          end

          def test_parse_active_job_with_empty_args_returns_nil_values
            job = {
              "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
              "queue" => "default",
              "args" => []
            }

            result = JobParser.parse(job)

            assert_nil result[:queue]
            assert_nil result[:job_class]
          end

          def test_parse_active_job_with_non_hash_payload_returns_nil_values
            job = {
              "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
              "queue" => "default",
              "args" => ["string instead of hash"]
            }

            result = JobParser.parse(job)

            assert_nil result[:queue]
            assert_nil result[:job_class]
          end

          def test_extract_queue_returns_only_queue
            job = {"class" => "TestJob", "queue" => "critical", "args" => []}

            assert_equal "critical", JobParser.extract_queue(job)
          end

          def test_extract_job_class_returns_only_class
            job = {"class" => "TestJob", "queue" => "critical", "args" => []}

            assert_equal "TestJob", JobParser.extract_job_class(job)
          end

          def test_parse_converts_symbol_queue_to_string
            job = {"class" => "TestJob", "queue" => :default, "args" => []}

            result = JobParser.parse(job)

            assert_equal "default", result[:queue]
            assert_instance_of String, result[:queue]
          end

          def test_parse_converts_symbol_class_to_string
            job = {"class" => :TestJob, "queue" => "default", "args" => []}

            result = JobParser.parse(job)

            assert_equal "TestJob", result[:job_class]
            assert_instance_of String, result[:job_class]
          end
        end
      end
    end
  end
end
