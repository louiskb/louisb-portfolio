require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "ai_configured? is false when ANTHROPIC_API_KEY is absent" do
    with_env("ANTHROPIC_API_KEY", nil) do
      assert_not ai_configured?
    end
  end

  test "ai_configured? is true when ANTHROPIC_API_KEY is present" do
    with_env("ANTHROPIC_API_KEY", "sk-ant-test-key") do
      assert ai_configured?
    end
  end

  test "posthog_enabled? is false when POSTHOG_PROJECT_TOKEN is absent" do
    with_env("POSTHOG_PROJECT_TOKEN", nil) do
      assert_not posthog_enabled?
    end
  end

  test "posthog_enabled? is true when POSTHOG_PROJECT_TOKEN is present" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      assert posthog_enabled?
    end
  end
end
