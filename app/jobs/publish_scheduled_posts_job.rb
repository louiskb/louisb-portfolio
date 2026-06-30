# Publishes content whose scheduled publish time has arrived.
#
# Solid Queue's recurring scheduler runs this every minute (see config/recurring.yml).
# Any BlogPost or Project in the `scheduled` state whose `scheduled_at` is now in
# the past is flipped to `published` via the Publishable concern's `publish!`,
# which also clears `scheduled_at` (cleaner than a bare `published!` that would
# leave a stale schedule time behind).
class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

  def perform
    # Beginless range → `scheduled_at <= Time.current`. NULL scheduled_at rows
    # never satisfy `<=`, so they're excluded automatically.
    due = ..Time.current

    BlogPost.scheduled.where(scheduled_at: due).find_each do |post|
      post.publish!
      Rails.logger.info "PublishScheduledPostsJob: published BlogPost ##{post.id} \"#{post.title}\""
    end

    Project.scheduled.where(scheduled_at: due).find_each do |project|
      project.publish!
      Rails.logger.info "PublishScheduledPostsJob: published Project ##{project.id} \"#{project.title}\""
    end
  end
end
