# app/jobs/retry_failed_webhooks_job.rb
class RetryFailedWebhooksJob < ApplicationJob
  queue_as :low_priority
  
  def perform
    # Retry failed webhooks that are less than 24 hours old
    failed_webhooks = WebhookEvent.failed
                                 .where('created_at > ?', 24.hours.ago)
                                 .order(:created_at)
                                 .limit(50)
    
    failed_webhooks.each do |webhook|
      case webhook.event_type
      when 'transfer_status'
        ProcessTransferStatusJob.perform_later(webhook.id)
      when 'consent_status'
        ProcessConsentStatusJob.perform_later(webhook.id)
      end
    end
  end
end