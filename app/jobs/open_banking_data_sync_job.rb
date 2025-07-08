# app/jobs/open_banking_data_sync_job.rb (Updated)
class OpenBankingDataSyncJob < ApplicationJob
  queue_as :default
  
  def perform(bank_connection_id, force_refresh = false)
    bank_connection = BankConnection.find(bank_connection_id)
    return unless bank_connection.active? || force_refresh
    
    begin
      # Refresh token if needed
      if bank_connection.needs_token_refresh?
        unless bank_connection.refresh_access_token!
          Rails.logger.error "Failed to refresh token for connection #{bank_connection_id}"
          return
        end
      end
      
      api_service = bank_connection.api_service
      
      # Sync accounts first
      sync_accounts(api_service, bank_connection)
      
      # Sync transactions for each account
      sync_all_transactions(api_service, bank_connection)
      
      bank_connection.update!(last_synced_at: Time.current)
      
    rescue OpenBankingApiService::OpenBankingError => e
      Rails.logger.error "Open Banking sync failed for connection #{bank_connection_id}: #{e.message}"
      bank_connection.handle_api_error(e)
    rescue => e
      Rails.logger.error "Unexpected error during sync for connection #{bank_connection_id}: #{e.message}"
      bank_connection.update!(status: 'error', error_message: e.message)
    end
  end
  
  private
  
  def sync_accounts(api_service, bank_connection)
    accounts_data = api_service.get_accounts
    
    accounts_data.dig('data', 'accounts')&.each do |account_data|
      # Sync account balance
      balance_data = api_service.get_account_balance(account_data['account_number'])
      
      bank_connection.account_balances.create!(
        account_number: account_data['account_number'],
        current_balance: balance_data.dig('data', 'current_balance'),
        available_balance: balance_data.dig('data', 'available_balance'),
        ledger_balance: balance_data.dig('data', 'ledger_balance'),
        balance_date: Time.current,
        metadata: balance_data['data']
      )
    end
  end
  
  def sync_all_transactions(api_service, bank_connection)
    # Get all account numbers from recent balance records
    account_numbers = bank_connection.account_balances
                                   .select(:account_number)
                                   .distinct
                                   .pluck(:account_number)
    
    account_numbers.each do |account_number|
      sync_account_transactions(api_service, bank_connection, account_number)
    end
  end
  
  def sync_account_transactions(api_service, bank_connection, account_number)
    from_date = bank_connection.last_synced_at || 90.days.ago
    to_date = Time.current
    
    transactions_data = api_service.get_account_transactions(
      account_number,
      from_date,
      to_date
    )
    
    transactions_data.dig('data', 'transactions')&.each do |txn_data|
      next if bank_connection.transactions.exists?(external_transaction_id: txn_data['id'])
      
      bank_connection.transactions.create!(
        external_transaction_id: txn_data['id'],
        account_number: account_number,
        amount: txn_data['amount'],
        transaction_type: txn_data['type'],
        description: txn_data['description'],
        reference: txn_data['reference'],
        transaction_date: Date.parse(txn_data['date']),
        balance_after: txn_data['balance_after'],
        metadata: txn_data
      )
    end
  end
end