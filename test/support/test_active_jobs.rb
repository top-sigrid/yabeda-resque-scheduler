# frozen_string_literal: true

require "active_job"

# Configure ActiveJob to use Resque adapter
ActiveJob::Base.queue_adapter = :resque

# Silence ActiveJob logging in tests
ActiveJob::Base.logger = Logger.new(nil)

# Sample test ActiveJob classes
class TestActiveJob < ActiveJob::Base
  queue_as :active_job_queue

  def perform(*args)
  end
end

class AnotherActiveJob < ActiveJob::Base
  queue_as :notifications

  def perform(*args)
  end
end

class ParserTestActiveJob < ActiveJob::Base
  queue_as :parser_test_queue

  def perform(*args)
  end
end
