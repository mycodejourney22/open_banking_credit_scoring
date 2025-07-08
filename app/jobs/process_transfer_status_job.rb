# app/jobs/process_transfer_status_job.rb
class ProcessTransferStatusJob < ApplicationJob
  queue_as :webhooks
  
  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find(webhook_event_id)
    webhook_event.mark_processing!
    
    begin
      payload = webhook_event.payload
      reference = payload.dig('data', 'reference')
      status = payload.dig('data', 'status')
      status_message = payload.dig('data', 'status_message')
      
      # Find related transaction or bill payment by reference
      if transaction = Transaction.find_by(reference: reference)
        transaction.update!(
          status: status.downcase,
          metadata: transaction.metadata.merge(
            'webhook_status' => status,
            'webhook_message' => status_message,
            'updated_at' => Time.current.iso8601
          )
        )
      elsif bill_payment = BillPayment.find_by(external_reference: reference)
        bill_payment.update!(
          status: status,
          status_message: status_message,
          completed_at: Time.current,
          metadata: bill_payment.metadata.merge(
            'webhook_status' => status,
            'webhook_message' => status_message,
            'updated_at' => Time.current.iso8601
          )
        )
      else
        Rails.logger.warn "No transaction or bill payment found for reference: #{reference}"
      end
      
      webhook_event.mark_completed!
      
    rescue => e
      Rails.logger.error "Failed to process transfer status webhook: #{e.message}"
      webhook_event.mark_failed!(e.message)
    end
  end
end
