# Be sure to restart your server when you modify this file.

# Content-Security-Policy — the browser-side backstop for a site that
# deliberately renders AI-authored HTML (blog html_content): even if something
# slipped past the server-side sanitize allowlist, the browser would still
# refuse to run scripts that aren't same-origin + nonce-tagged, post forms
# off-site, or load plugins.
#
# Every origin below is one the app actually uses:
#   fonts.googleapis.com / fonts.gstatic.com — the four Depth Charge fonts
#   *.i.posthog.com                          — analytics script + event ingest
#   api.cloudinary.com                       — Active Storage direct uploads (Trix)
#   www.youtube-nocookie.com                 — the two homepage video embeds
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.object_src  :none
    policy.form_action :self
    policy.frame_ancestors :self
    # Scripts: same-origin or carrying this request's nonce (the importmap and
    # PostHog boot snippets are inline <script> tags), plus the PostHog CDN.
    policy.script_src  :self, "https://*.i.posthog.com"
    # Styles: Bootstrap components and Trix set style="" attributes at
    # runtime, and sanitized blog HTML legitimately carries a style attribute —
    # so inline styles stay allowed. Inline STYLE can't execute code.
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src    :self, "https://fonts.gstatic.com", :data
    # Images may come from Cloudinary, Unsplash, or any https URL stored in the
    # legacy img_url columns; images can't execute, so https: is acceptable.
    # blob: covers Trix's local attachment previews.
    policy.img_src     :self, :https, :data, :blob
    policy.frame_src   "https://www.youtube-nocookie.com"
    policy.connect_src :self, "https://*.i.posthog.com", "https://api.cloudinary.com"
  end

  # Nonce: a per-session random value stamped onto approved inline <script>
  # tags; the header names the same value, so injected inline scripts (which
  # can't know the nonce) are refused. Session-keyed (not per-request) so
  # Turbo's page cache can restore pages without breaking their scripts.
  config.content_security_policy_nonce_generator  = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]
end
