# app/jobs/cleanup_old_data_job.rb
class CleanupOldDataJob < ApplicationJob
  queue_as :low_priority
  
  def perform
    # Clean up old webhook events (older than 30 days)
    WebhookEvent.where('created_at < ?', 30.days.ago).delete_all
    
    # Clean up old account balances (keep only latest 100 per connection)
    BankConnection.includes(:account_balances).find_each do |connection|
      old_balances = connection.account_balances
                              .order(created_at: :desc)
                              .offset(100)
      old_balances.delete_all if old_balances.exists?
    end
    
    # Clean up expired/revoked connections (older than 90 days)
    old_connections = BankConnection.where(status: ['expired', 'revoked'])
                                   .where('updated_at < ?', 90.days.ago)
    
    old_connections.destroy_all
    
    Rails.logger.info "Cleanup completed: removed old webhook events and connection data"
  end
end