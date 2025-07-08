# app/jobs/process_consent_status_job.rb
class ProcessConsentStatusJob < ApplicationJob
  queue_as :webhooks
  
  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find(webhook_event_id)
    webhook_event.mark_processing!
    
    begin
      payload = webhook_event.payload
      consent_id = payload.dig('data', 'consent_id')
      status = payload.dig('data', 'consent_status')
      
      # Find bank connection by consent token or other identifier
      bank_connection = BankConnection.find_by(consent_token: consent_id) ||
                       BankConnection.find_by(device_code: payload.dig('data', 'device_code'))
      
      if bank_connection
        case status.downcase
        when 'approved'
          # Consent approved - connection should already be active via polling
          bank_connection.update!(status: 'active') unless bank_connection.active?
        when 'revoked', 'expired'
          bank_connection.update!(status: status.downcase)
        when 'rejected'
          bank_connection.update!(status: 'revoked')
        end
      else
        Rails.logger.warn "No bank connection found for consent webhook: #{consent_id}"
      end
      
      webhook_event.mark_completed!
      
    rescue => e
      Rails.logger.error "Failed to process consent status webhook: #{e.message}"
      webhook_event.mark_failed!(e.message)
    end
  end
end