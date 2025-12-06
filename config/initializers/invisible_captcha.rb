InvisibleCaptcha.setup do |config|
  config.time_limit = 5.seconds
  config.honeypot_field_names = ["nickname", "phone"]
  config.throttle = 10.minutes
  config.throttle_max_hits = 3
  config.verbose_rate_limit_logs = true # Logs all blocks to Rails log
end
