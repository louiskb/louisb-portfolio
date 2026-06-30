module ApplicationHelper
  def nav_link_class(path = "#")
    current_page?(path) ? "nav-link active fs-5" : "nav-link fs-5"
  end

  def nav_link_dropdown_class(path = "#")
    current_page?(path) ? "dropdown-item active fs-5" : "dropdown-item fs-5"
  end

  # True when an Anthropic API key is configured, which enables the AI blog
  # features. When false, the AI menu entries and pages render a friendly
  # "set ANTHROPIC_API_KEY" notice instead of erroring. Controllers reach this
  # via the `helpers` proxy (e.g. helpers.ai_configured?).
  def ai_configured?
    ENV["ANTHROPIC_API_KEY"].present?
  end

  # True when a PostHog project token is configured, which enables cookieless
  # visitor analytics (the client snippet and server-side events). When false,
  # the analytics snippet is omitted and every server-side event is a no-op, so
  # the app runs identically with analytics simply switched off.
  def posthog_enabled?
    ENV["POSTHOG_PROJECT_TOKEN"].present?
  end
end
