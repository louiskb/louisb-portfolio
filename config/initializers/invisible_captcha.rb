InvisibleCaptcha.setup do |config|
  config.timestamp_threshold = 5
  # The timestamp + spinner checks both rely on tokens injected when the form is
  # rendered; a fast direct test POST has neither, so both flag legit requests as
  # spam. Disable both in test only — the honeypot fields stay active in every
  # environment, which is the primary defense.
  config.timestamp_enabled = !Rails.env.test?
  config.spinner_enabled = !Rails.env.test?
  config.honeypots = ["nickname", "website_url", "company", "subject"]
  # `invisible_captcha` always logs spam blocks to log/development.log. In development: Check log/development.log in your Rails root run in terminal: `tail -f log/development.log | grep "InvisibleCaptcha"`. Live on Heroku run: `heroku logs --tail | grep InvisibleCaptcha`.
  # Refer to `invisible_captcha` README https://github.com/markets/invisible_captcha
end
