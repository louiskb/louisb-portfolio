require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LouisbPortfolio
  class Application < Rails::Application
    config.action_controller.raise_on_missing_callback_actions = false if Rails.version >= "7.1.0"
    config.generators do |generate|
      generate.assets false
      generate.helper false
      generate.test_framework :test_unit, fixture: false
    end
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Louis is based in Thailand; using his timezone makes scheduled-publish
    # times (entered via datetime-local in Phase 4) read as his local time.
    config.time_zone = "Bangkok"

    # We do not use Active Storage variants (image_processing is not bundled);
    # blobs render at full size. Make that explicit so a stray variant call
    # fails loudly instead of silently depending on an absent processor.
    config.active_storage.variant_processor = :disabled
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
