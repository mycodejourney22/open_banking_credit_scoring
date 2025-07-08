# app/jobs/token_refresh_job.rb
class TokenRefreshJob < ApplicationJob
  queue_as :default
  
  def perform
    # Find connections that need token refresh
    connections_needing_refresh = BankConnection.active
                                               .needs_refresh
                                               .where('last_synced_at > ?', 7.days.ago)
    
    connections_needing_refresh.find_each do |connection|
      if connection.refresh_access_token!
        Rails.logger.info "Successfully refreshed token for connection #{connection.id}"
        
        # Schedule a sync after successful refresh
        OpenBankingDataSyncJob.perform_later(connection.id)
      else
        Rails.logger.warn "Failed to refresh token for connection #{connection.id}"
      end
    end
  end
end