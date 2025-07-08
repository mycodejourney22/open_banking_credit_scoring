Rails.application.configure do
    # Open Banking configuration
    config.x.open_banking = {
      webhook_timeout: 30.seconds,
      max_retry_attempts: 3,
      sync_interval: 4.hours,
      token_refresh_threshold: 1.hour,
      cleanup_interval: 1.day
    }
end