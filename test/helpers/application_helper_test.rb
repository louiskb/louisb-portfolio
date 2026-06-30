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

  private

  # Temporarily set (or unset, when value is nil) an env var, restoring the
  # original afterwards. Test processes are isolated, so this is leak-free.
  def with_env(key, value)
    original = ENV[key]
    value.nil? ? ENV.delete(key) : ENV[key] = value
    yield
  ensure
    original.nil? ? ENV.delete(key) : ENV[key] = original
  end
end
