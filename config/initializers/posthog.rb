# PostHog analytics — server-side configuration (GUARDED).
#
# The entire block is wrapped in a token-presence guard so the app is a complete
# no-op when POSTHOG_PROJECT_TOKEN is absent: no client is initialised, nothing
# flushes against a nil host, and no exception capture targets a missing
# endpoint. Analytics simply stay off until the token is set (see the matching
# `posthog_enabled?` helper).
#
# NOTE: unlike the reference app, this deliberately OMITS the `capture_user_context`
# / `current_user_method` / `user_id_method` lines — they reference a
# `posthog_distinct_id` method that does not exist (a latent bug there), and
# visitor-only, cookieless tracking needs no per-user context anyway.
if ENV["POSTHOG_PROJECT_TOKEN"].present?
  PostHog.init do |config|
    config.api_key = ENV.fetch("POSTHOG_PROJECT_TOKEN", nil)
    config.host = ENV.fetch("POSTHOG_HOST", nil)
  end

  PostHog::Rails.configure do |config|
    # Auto-capture unhandled exceptions in controllers.
    config.auto_capture_exceptions = true

    # Also capture exceptions that Rails rescues (e.g. ActiveRecord::RecordNotFound).
    config.report_rescued_exceptions = true

    # Auto-instrument ActiveJob failures.
    config.auto_instrument_active_job = true
  end
end
