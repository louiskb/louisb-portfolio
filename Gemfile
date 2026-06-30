source "https://rubygems.org"

ruby "3.3.5"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Database-backed Active Job adapter (background jobs + scheduled publishing).
# Runs in-Puma on the primary DB — no separate worker dyno, no Solid Cache/Cable.
gem "solid_queue", "~> 1.3"

# Active Storage variants are intentionally disabled; we render originals.
# gem "image_processing", "~> 1.2"

gem "bootstrap", "~> 5.3"
gem "devise", "~> 5.0"
gem "autoprefixer-rails"
gem "font-awesome-sass", "~> 6.1"
gem "simple_form", github: "heartcombo/simple_form"
gem "sassc-rails"

# Slug URLs for blog posts and projects
gem "friendly_id", "~> 5.6"

# Pagination
gem "pagy", "~> 43.3"

# Image uploads via Active Storage (Cloudinary service in production)
gem "cloudinary", "~> 2.4"

# AI blog generation/revision (configured for Anthropic Claude)
gem "ruby_llm"

# Contact-form spam protection
gem "invisible_captcha"

# Cookieless, visitor-only product analytics
gem "posthog-ruby", "~> 3.6"
gem "posthog-rails", "~> 3.6"

group :development, :test do
  gem "dotenv-rails"
  gem "faker"
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
  # gem "letter_opener"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
