require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpenBankingCreditScoring
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))
    config.time_zone = 'West Central Africa'

    config.turbo.draw_routes = false

    config.active_job.queue_adapter = :sidekiq

    config.open_banking_api_base_url = ENV.fetch('OPEN_BANKING_API_URL', 'https://apis.openbanking.ng')
    config.open_banking_client_id = ENV.fetch('OPEN_BANKING_CLIENT_ID', '1234567890')
    config.open_banking_client_secret = ENV.fetch('OPEN_BANKING_CLIENT_SECRET', '1234567890')

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
