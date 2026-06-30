require "test_helper"

# Server-side visitor analytics. Every event is visitor-only (signed-out),
# fires once, and uses distinct_id "anonymous". PostHog.capture is stubbed in
# every test, so no analytics request ever leaves the process.
class PosthogEventsTest < ActionDispatch::IntegrationTest
  # ---- blog_post_viewed ----

  test "visitor viewing a blog post fires exactly one blog_post_viewed event" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      events = capture_posthog_events do
        get blog_post_url(blog_posts(:welcome))
        assert_response :success
      end
      assert_equal 1, events.size
      assert_equal "blog_post_viewed", events.first[:event]
      assert_equal "anonymous", events.first[:distinct_id]
    end
  end

  test "signed-in owner viewing a blog post fires no event" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      sign_in users(:louis)
      events = capture_posthog_events do
        get blog_post_url(blog_posts(:welcome))
        assert_response :success
      end
      assert_empty events
    end
  end

  test "viewing a blog post fires no event without a token" do
    with_env("POSTHOG_PROJECT_TOKEN", nil) do
      events = capture_posthog_events do
        get blog_post_url(blog_posts(:welcome))
        assert_response :success
      end
      assert_empty events
    end
  end

  # ---- project_viewed ----

  test "visitor viewing a project fires exactly one project_viewed event" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      events = capture_posthog_events do
        get project_url(projects(:sipfolio))
        assert_response :success
      end
      assert_equal 1, events.size
      assert_equal "project_viewed", events.first[:event]
      assert_equal "anonymous", events.first[:distinct_id]
    end
  end

  test "signed-in owner viewing a project fires no event" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      sign_in users(:louis)
      events = capture_posthog_events do
        get project_url(projects(:sipfolio))
        assert_response :success
      end
      assert_empty events
    end
  end

  # ---- contact_submitted ----

  test "visitor submitting the contact form fires exactly one contact_submitted event" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      events = capture_posthog_events do
        post contacts_url, params: { contact: {
          first_name: "Sam", last_name: "Visitor",
          email: "sam@example.com", message: "Hi Louis!"
        } }
        assert_response :redirect
      end
      assert_equal 1, events.size
      assert_equal "contact_submitted", events.first[:event]
    end
  end

  test "a failed contact submission fires no event" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      events = capture_posthog_events do
        post contacts_url, params: { contact: {
          first_name: "", last_name: "", email: "nope", message: ""
        } }
      end
      assert_empty events
    end
  end

  # ---- resume_downloaded + endpoint ----

  test "GET /resume returns the PDF for a signed-out visitor" do
    get resume_url
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "visitor downloading the resume fires exactly one resume_downloaded event" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      events = capture_posthog_events do
        get resume_url
        assert_response :success
      end
      assert_equal 1, events.size
      assert_equal "resume_downloaded", events.first[:event]
      assert_equal "anonymous", events.first[:distinct_id]
    end
  end

  test "signed-in owner downloading the resume fires no event but still gets the PDF" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      sign_in users(:louis)
      events = capture_posthog_events do
        get resume_url
        assert_response :success
        assert_equal "application/pdf", response.media_type
      end
      assert_empty events
    end
  end
end
