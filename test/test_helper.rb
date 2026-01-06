# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "securerandom"
require "resque"
require "resque-scheduler"
require "yabeda/resque/scheduler"

require "minitest/autorun"

Resque.redis = Redis.new(host: "localhost", port: 6379, db: 15)

Resque::Scheduler.quiet = true

require_relative "support/redis_helper"
require_relative "support/resque_helper"
require_relative "support/test_jobs"
require_relative "support/test_active_jobs"

module Minitest
  class Test
    include RedisHelper
    include ResqueHelper
  end
end
