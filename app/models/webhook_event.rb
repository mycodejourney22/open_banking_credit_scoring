# app/models/webhook_event.rb
class WebhookEvent < ApplicationRecord
    validates :event_type, presence: true
    validates :event_id, presence: true, uniqueness: { scope: :event_type }
    validates :source, presence: true
    validates :status, inclusion: { in: %w[pending processing completed failed] }
    
    enum status: {
      pending: 'pending',
      processing: 'processing',
      completed: 'completed',
      failed: 'failed'
    }
    
    scope :unprocessed, -> { where(status: ['pending', 'failed']) }
    scope :recent, -> { order(created_at: :desc) }
    
    def mark_processing!
      update!(status: 'processing', processed_at: Time.current)
    end
    
    def mark_completed!
      update!(status: 'completed', processed_at: Time.current, error_message: nil)
    end
    
    def mark_failed!(error_message)
      update!(status: 'failed', error_message: error_message, processed_at: Time.current)
    end
end