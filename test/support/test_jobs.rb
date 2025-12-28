# frozen_string_literal: true

# Sample test job classes for native Resque jobs
class TestJob
  @queue = :default

  def self.perform(*args)
  end
end

class AnotherTestJob
  @queue = :high

  def self.perform(*args)
  end
end

class MailerJob
  @queue = :mailers

  def self.perform(*args)
  end
end
