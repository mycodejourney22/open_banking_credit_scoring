# app/jobs/open_banking_data_sync_job.rb (Fixed Version)
class OpenBankingDataSyncJob < ApplicationJob
  queue_as :default
  
  # Add delays between different connection syncs
  def perform(bank_connection_id, force_refresh = false)
    bank_connection = BankConnection.find(bank_connection_id)
    return unless bank_connection.active? || force_refresh
    
    # Check if we've synced recently to avoid unnecessary calls
    if !force_refresh && bank_connection.last_synced_at && bank_connection.last_synced_at > 1.hour.ago
      Rails.logger.info "Skipping sync for connection #{bank_connection_id} - synced recently"
      return
    end
    
    begin
      # Refresh token if needed
      if bank_connection.needs_token_refresh?
        unless refresh_token_safely(bank_connection)
          Rails.logger.error "Failed to refresh token for connection #{bank_connection_id}"
          return
        end
      end
      
      api_service = bank_connection.api_service
      
      # Use rate limiting for all API calls
      sync_with_rate_limiting(api_service, bank_connection)
      
      bank_connection.update!(last_synced_at: Time.current)
      Rails.logger.info "Successfully synced connection #{bank_connection_id}"
      
    rescue OpenBankingApiService::OpenBankingError => e
      handle_sync_error(bank_connection, e)
    rescue => e
      Rails.logger.error "Unexpected error during sync for connection #{bank_connection_id}: #{e.message}"
      bank_connection.update!(status: 'error', error_message: e.message)
    end
  end
  
  private
  
  def refresh_token_safely(bank_connection)
    RateLimitHandler.with_rate_limiting(context: "token_refresh_#{bank_connection.id}") do
      bank_connection.refresh_access_token!
    end
  rescue => e
    Rails.logger.error "Token refresh failed: #{e.message}"
    false
  end
  
  def sync_with_rate_limiting(api_service, bank_connection)
    # First, get accounts with rate limiting
    accounts_data = RateLimitHandler.with_rate_limiting(context: "accounts_#{bank_connection.id}") do
      api_service.get_accounts
    end
    
    return unless accounts_data&.dig('data', 'accounts')
    
    # Process accounts one by one with delays
    accounts_data['data']['accounts'].each_with_index do |account_data, index|
      # Add delay between accounts to respect rate limits
      sleep(2) if index > 0
      
      begin
        sync_single_account(api_service, bank_connection, account_data)
      rescue OpenBankingApiService::OpenBankingError => e
        Rails.logger.warn "Failed to sync account #{account_data['account_number']}: #{e.message}"
        # Continue with other accounts instead of failing completely
        next
      end
    end
  end
  
  def sync_single_account(api_service, bank_connection, account_data)
    account_number = account_data['account_number']
    
    # Sync account balance with rate limiting
    balance_data = RateLimitHandler.with_rate_limiting(context: "balance_#{account_number}") do
      api_service.get_account_balance(account_number)
    end
    
    if balance_data&.dig('data')
      # Only create new balance record if significantly different or it's been a day
      latest_balance = bank_connection.account_balances
                                    .where(account_number: account_number)
                                    .order(:balance_date)
                                    .last
      
      should_create_balance = latest_balance.nil? || 
                            latest_balance.balance_date < 1.day.ago ||
                            (latest_balance.current_balance - balance_data.dig('data', 'current_balance')).abs > 1000
      
      if should_create_balance
        bank_connection.account_balances.create!(
          account_number: account_number,
          current_balance: balance_data.dig('data', 'current_balance') || 0,
          available_balance: balance_data.dig('data', 'available_balance') || 0,
          ledger_balance: balance_data.dig('data', 'ledger_balance') || 0,
          balance_date: Time.current,
          metadata: balance_data['data']
        )
      end
    end
    
    # Add delay before fetching transactions
    sleep(3)
    
    # Sync transactions with rate limiting - only get recent transactions
    from_date = [bank_connection.last_synced_at, 30.days.ago].compact.max
    to_date = Time.current
    
    transactions_data = RateLimitHandler.with_rate_limiting(context: "transactions_#{account_number}") do
      api_service.get_account_transactions(account_number, from_date, to_date)
    end
    
    if transactions_data&.dig('data', 'transactions')
      sync_transactions(bank_connection, account_number, transactions_data['data']['transactions'])
    end
  end
  
  def sync_transactions(bank_connection, account_number, transactions)
    return if transactions.empty?
    
    # Batch process transactions to avoid too many database calls
    new_transactions = []
    
    transactions.each do |txn_data|
      # Skip if transaction already exists
      next if bank_connection.transactions.exists?(external_transaction_id: txn_data['id'])
      
      new_transactions << {
        external_transaction_id: txn_data['id'],
        account_number: account_number,
        amount: parse_amount(txn_data['amount']),
        transaction_type: txn_data['type'] || 'UNKNOWN',
        description: txn_data['description'] || '',
        reference: txn_data['reference'] || '',
        transaction_date: parse_date(txn_data['date']),
        balance_after: parse_amount(txn_data['balance_after']),
        metadata: txn_data,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    # Bulk insert for better performance
    if new_transactions.any?
      bank_connection.transactions.insert_all(new_transactions)
      Rails.logger.info "Inserted #{new_transactions.size} new transactions for account #{account_number}"
    end
  end
  
  def handle_sync_error(bank_connection, error)
    case error.status_code
    when 401
      Rails.logger.warn "Authentication failed for connection #{bank_connection.id}, marking as expired"
      bank_connection.update!(status: 'expired', error_message: error.message)
    when 403
      Rails.logger.warn "Access denied for connection #{bank_connection.id}, marking as revoked"
      bank_connection.update!(status: 'revoked', error_message: error.message)
    when 429
      Rails.logger.warn "Rate limited for connection #{bank_connection.id}, will retry later"
      # Don't mark as error for rate limits, just log and retry later
    else
      Rails.logger.error "Open Banking sync failed for connection #{bank_connection.id}: #{error.message}"
      bank_connection.update!(status: 'error', error_message: error.message)
    end
  end
  
  def parse_amount(amount)
    return 0 if amount.nil?
    amount.to_f.round(2)
  end
  
  def parse_date(date_string)
    return Time.current if date_string.nil?
    Date.parse(date_string.to_s) rescue Time.current.to_date
  end
end