require "test_helper"

# The cookieless posthog-js snippet must render ONLY for a signed-out visitor
# AND only when a project token is configured — the site owner is never tracked,
# and an unconfigured app ships no analytics code at all.
class PosthogSnippetTest < ActionDispatch::IntegrationTest
  test "renders the posthog snippet for a signed-out visitor when a token is set" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      get root_url
      assert_response :success
      assert_includes response.body, "posthog.init", "snippet should render for visitors"
      assert_includes response.body, "phc_test", "the configured token should be embedded"
      assert_includes response.body, "disable_cookie", "snippet must be configured cookieless"
    end
  end

  test "omits the posthog snippet for the signed-in owner even when a token is set" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      sign_in users(:louis)
      get root_url
      assert_response :success
      assert_not_includes response.body, "posthog.init", "the owner must never be tracked"
    end
  end

  test "omits the posthog snippet when no token is configured" do
    with_env("POSTHOG_PROJECT_TOKEN", nil) do
      get root_url
      assert_response :success
      assert_not_includes response.body, "posthog.init", "no snippet without a token"
    end
  end
end
