# frozen_string_literal: true

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
