require "test_helper"

class PosthogInitializerTest < ActiveSupport::TestCase
  INITIALIZER = Rails.root.join("config/initializers/posthog.rb").to_s

  test "loading the initializer with no token does not raise" do
    # Graceful degradation: with no POSTHOG_PROJECT_TOKEN the initializer must be
    # a complete no-op and never crash boot.
    with_env("POSTHOG_PROJECT_TOKEN", nil) do
      assert_nothing_raised { load INITIALIZER }
    end
  end

  test "loading the initializer with no token does not call PostHog.init" do
    # The whole PostHog.init / configure block is guarded by the token's
    # presence, so an unconfigured app never initialises a client (which would
    # otherwise flush against a nil host).
    with_env("POSTHOG_PROJECT_TOKEN", nil) do
      init_called = false
      PostHog.stub(:init, ->(*_args, &_blk) { init_called = true }) do
        PostHog::Rails.stub(:configure, ->(*_args, &_blk) {}) do
          load INITIALIZER
        end
      end
      assert_not init_called, "PostHog.init must not run without a token"
    end
  end

  test "loading the initializer with a token calls PostHog.init" do
    with_env("POSTHOG_PROJECT_TOKEN", "phc_test") do
      init_called = false
      # Stub init/configure so the real client is never built and no global state
      # leaks into other tests.
      PostHog.stub(:init, ->(*_args, &_blk) { init_called = true }) do
        PostHog::Rails.stub(:configure, ->(*_args, &_blk) {}) do
          load INITIALIZER
        end
      end
      assert init_called, "PostHog.init must run when a token is present"
    end
  end
end
