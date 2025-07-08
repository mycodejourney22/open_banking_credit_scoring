# app/controllers/webhooks/open_banking_controller.rb
class Webhooks::OpenBankingController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_webhook_signature
    
    def transfer_status
      webhook_event = create_webhook_event('transfer_status')
      
      # Process transfer status update
      ProcessTransferStatusJob.perform_later(webhook_event.id)
      
      head :ok
    end
    
    def consent_status
      webhook_event = create_webhook_event('consent_status')
      
      # Process consent status update
      ProcessConsentStatusJob.perform_later(webhook_event.id)
      
      head :ok
    end
    
    private
    
    def verify_webhook_signature
      # Verify the webhook signature using the same method as API requests
      expected_signature = generate_signature(
        Rails.application.credentials.open_banking[:client_secret],
        request.headers['idempotency_key'],
        request.headers['Authorization']&.gsub('Bearer ', '')
      )
      
      received_signature = request.headers['signature']
      
      unless received_signature == expected_signature
        Rails.logger.warn "Invalid webhook signature: expected #{expected_signature}, received #{received_signature}"
        head :unauthorized and return
      end
    end
    
    def create_webhook_event(event_type)
      WebhookEvent.create!(
        event_type: event_type,
        event_id: request.headers['idempotency_key'] || SecureRandom.uuid,
        source: 'open_banking',
        payload: request.request_parameters,
        status: 'pending'
      )
    end
    
    def generate_signature(client_secret, idempotency_key, bearer_token = nil)
      signature_string = "#{client_secret};#{idempotency_key}"
      signature_string += ";#{bearer_token}" if bearer_token
      
      "SHA-256(#{Digest::SHA256.hexdigest(signature_string)})"
    end
end
  