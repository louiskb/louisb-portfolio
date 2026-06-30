require "test_helper"

class PublishScheduledPostsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:louis)
    @now = Time.zone.local(2026, 7, 1, 12, 0, 0)
  end

  test "publishes a scheduled blog post whose time has passed" do
    travel_to @now do
      post = BlogPost.create!(
        title: "Past scheduled post",
        html_content: "<p>Ready to go live.</p>",
        user: @user,
        status: :scheduled,
        scheduled_at: @now - 1.hour
      )

      PublishScheduledPostsJob.perform_now

      assert post.reload.published?, "expected a past-due scheduled post to be published"
      assert_nil post.scheduled_at, "expected scheduled_at to be cleared on publish"
    end
  end

  test "leaves a scheduled blog post whose time is still in the future" do
    travel_to @now do
      post = BlogPost.create!(
        title: "Future scheduled post",
        html_content: "<p>Not yet.</p>",
        user: @user,
        status: :scheduled,
        scheduled_at: @now + 1.hour
      )

      PublishScheduledPostsJob.perform_now

      assert post.reload.scheduled?, "expected a future-dated scheduled post to stay scheduled"
      assert_equal @now + 1.hour, post.scheduled_at
    end
  end

  test "publishes a scheduled project whose time has passed" do
    travel_to @now do
      project = Project.create!(
        title: "Past scheduled project",
        user: @user,
        status: :scheduled,
        scheduled_at: @now - 1.hour
      )

      PublishScheduledPostsJob.perform_now

      assert project.reload.published?, "expected a past-due scheduled project to be published"
      assert_nil project.scheduled_at, "expected scheduled_at to be cleared on publish"
    end
  end

  test "leaves a scheduled project whose time is still in the future" do
    travel_to @now do
      project = Project.create!(
        title: "Future scheduled project",
        user: @user,
        status: :scheduled,
        scheduled_at: @now + 1.hour
      )

      PublishScheduledPostsJob.perform_now

      assert project.reload.scheduled?, "expected a future-dated scheduled project to stay scheduled"
    end
  end

  test "leaves already-published records untouched" do
    travel_to @now do
      post = BlogPost.create!(
        title: "Already live post",
        html_content: "<p>Live.</p>",
        user: @user,
        status: :published
      )

      assert_no_changes -> { post.reload.updated_at } do
        PublishScheduledPostsJob.perform_now
      end
      assert post.reload.published?
    end
  end
end
