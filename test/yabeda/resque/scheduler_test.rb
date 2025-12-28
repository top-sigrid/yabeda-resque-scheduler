# frozen_string_literal: true

require "test_helper"

class Yabeda::Resque::SchedulerTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Yabeda::Resque::Scheduler::VERSION
  end
end
