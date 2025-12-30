# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "securerandom"
require "resque"
require "resque-scheduler"
require "yabeda/resque/scheduler"

require "minitest/autorun"

# Configure Redis for tests (use db 15 to isolate from development)
Resque.redis = Redis.new(host: "localhost", port: 6379, db: 15)

# Silence resque-scheduler logging in tests
Resque::Scheduler.quiet = true

# Load test support files
require_relative "support/redis_helper"
require_relative "support/resque_helper"
require_relative "support/test_jobs"
require_relative "support/test_active_jobs"

# Include helpers in all tests
module Minitest
  class Test
    include RedisHelper
    include ResqueHelper
  end
end
