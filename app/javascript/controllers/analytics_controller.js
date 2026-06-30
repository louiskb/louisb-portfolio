import { Controller } from "@hotwired/stimulus"

// Captures visitor analytics events via PostHog.
// Attach to any element with data-controller="analytics" and wire up actions.
//
// Usage examples:
//   data-action="click->analytics#trackClick"
//   data-analytics-event-value="cta_clicked"
//   data-analytics-properties-value='{"cta_name":"Contact Me","page":"home"}'
//
// For external links (auto-captures href + link text):
//   data-action="click->analytics#trackExternal"
//
// Every method guards on window.posthog, so it is a safe no-op when the snippet
// is absent (signed-in owner, or no token configured).
export default class extends Controller {
  static values = {
    event: String,
    properties: { type: Object, default: {} }
  }

  // Generic click tracker — uses event + properties values from data attributes
  trackClick() {
    this._capture(this.eventValue, this.propertiesValue)
  }

  // Track external link clicks — auto-captures href and link text
  trackExternal(event) {
    const link = event.currentTarget
    this._capture("external_link_clicked", {
      url: link.href,
      link_text: (link.title || link.getAttribute("aria-label") || link.textContent || "").trim(),
      page: this._currentPage()
    })
  }

  // Track social link clicks — captures platform from title or aria-label
  trackSocial(event) {
    const link = event.currentTarget
    this._capture("social_link_clicked", {
      platform: (link.title || link.getAttribute("aria-label") || "").trim(),
      location: this.propertiesValue.location || "unknown",
      page: this._currentPage()
    })
  }

  // Track navbar link clicks
  trackNav(event) {
    const link = event.currentTarget
    this._capture("nav_link_clicked", {
      link_name: link.textContent.trim(),
      from_page: this._currentPage()
    })
  }

  // Track footer link clicks
  trackFooter(event) {
    const link = event.currentTarget
    this._capture("footer_link_clicked", {
      link_name: link.textContent.trim(),
      page: this._currentPage()
    })
  }

  // Track CTA button clicks
  trackCta() {
    this._capture("cta_clicked", {
      cta_name: this.propertiesValue.cta_name || "unknown",
      page: this._currentPage()
    })
  }

  // Capture helper — guards against PostHog not being loaded
  _capture(event, properties = {}) {
    if (typeof window.posthog === "undefined" || !window.posthog.capture) return
    window.posthog.capture(event, properties)
  }

  _currentPage() {
    return window.location.pathname
  }
}
