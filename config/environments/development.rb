require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  # Settings specified here will take precedence over those in config/application.rb.

  # For Letter Opener (default development testing):
  # Toggle gem "letter_opener" in gem file and run `bundle install`.
  #(Toggle line below on/off to inspect email content when contact form is submitted with Letter Opener Gem). Don't forget to restart server after toggle. Also toggle off the development Proton smtp_settings and smtp delivery_method and vice versa if you need Letter Opener on.
  # config.action_mailer.delivery_method = :letter_opener

  # Toggle off the code SMTP code below when using Letter Opener Gem (toggle on code line above). After restart server.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "127.0.0.1",
    port: 1025,
    user_name: ENV["PM_USERNAME"],
    password: ENV["PM_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: false # Bridge handles encryption already
  }

  # Toggle the below line if `deliver_later` is used in the `contact_controller`. The `queue_adapter` is the "worker" that runs background jobs and thus the queued emails if `deliver_later` is set. Ideal for development but not recommended for production (since it dies when the server restarts). It's recommended to use a real worker like `Sidekiq` in production.
  # config.active_job.queue_adapter = :async

  # ------------------ End of email configuration settings ---------------------

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = true
end
