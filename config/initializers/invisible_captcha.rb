InvisibleCaptcha.setup do |config|
  config.time_limit = 5.seconds
  config.honeypot_field_names = ["nickname", "phone"]
  config.throttle = 10.minutes
  config.throttle_max_hits = 3
  config.verbose_rate_limit_logs = true # Logs all blocks to Rails log. In development: Check log/development.log in your Rails root run in terminal: `tail -f log/development.log | grep "InvisibleCaptcha"`. Live on Heroku run: `heroku logs --tail | grep InvisibleCaptcha`. 
end
