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
end
