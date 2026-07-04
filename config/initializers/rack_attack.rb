# Rate-limits the login endpoint. This is a single-owner site: nobody but
# Louis ever signs in legitimately, so unlimited POSTs to /users/sign_in only
# serve password-guessing bots. Two throttles cover the two guessing shapes:
#
#   * one IP hammering the form (throttle by IP)
#   * a botnet rotating IPs against the one known email (throttle by email)
#
# Counters live in Rails.cache. In development the cache is a null store
# unless `rails dev:cache` is toggled on, so the throttles are effectively
# inactive there — that's fine; they matter in production.
class Rack::Attack
  throttle("logins/ip", limit: 10, period: 3.minutes) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/users/sign_in" && req.post?
      # Normalised so "Email@X.com" and "email@x.com" share one counter.
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end
end

# Tests sign in repeatedly and must never trip a throttle.
Rack::Attack.enabled = !Rails.env.test?
