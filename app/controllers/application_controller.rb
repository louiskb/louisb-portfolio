class ApplicationController < ActionController::Base
  include Pagy::Method

  before_action :authenticate_user!

  private

  # Fires a visitor-only PostHog event. No-ops unless analytics is enabled
  # (POSTHOG_PROJECT_TOKEN present) AND the requester is a signed-out visitor —
  # the site owner is never tracked. distinct_id is always "anonymous" so no
  # visitor is personally identified: this is aggregate, cookieless analytics.
  def track_event(name, props = {})
    return unless helpers.posthog_enabled?
    return if user_signed_in?

    PostHog.capture(distinct_id: "anonymous", event: name, properties: props)
  end
end
