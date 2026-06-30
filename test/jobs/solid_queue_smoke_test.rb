require "test_helper"

class SolidQueueSmokeTest < ActiveJob::TestCase
  class NoopJob < ApplicationJob
    def perform; end
  end

  test "jobs enqueue through Active Job" do
    assert_enqueued_with(job: NoopJob) do
      NoopJob.perform_later
    end
  end

  test "solid_queue tables live in the primary database" do
    connection = ActiveRecord::Base.connection
    assert connection.table_exists?("solid_queue_jobs"),
           "expected solid_queue_jobs in the primary database"
    assert connection.table_exists?("solid_queue_recurring_tasks"),
           "expected solid_queue_recurring_tasks in the primary database"
  end
end
