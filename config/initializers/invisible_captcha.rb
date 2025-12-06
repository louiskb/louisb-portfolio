InvisibleCaptcha.setup do |config|
  config.timestamp_threshold = 5
  config.honeypots = ["nickname", "phone"]
  # `invisible_captcha` always logs spam blocks to log/development.log. In development: Check log/development.log in your Rails root run in terminal: `tail -f log/development.log | grep "InvisibleCaptcha"`. Live on Heroku run: `heroku logs --tail | grep InvisibleCaptcha`.
end
