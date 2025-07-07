# app/jobs/open_banking_data_sync_job.rb
class OpenBankingDataSyncJob < ApplicationJob
  queue_as :default

  def perform(bank_connection_id)
    bank_connection = BankConnection.find(bank_connection_id)
    return unless bank_connection.status == 'active'

    begin
      # Refresh token if needed
      refresh_token_if_needed(bank_connection)
      
      api_service = OpenBankingApiService.new(bank_connection.access_token)
      
      # Sync account balance
      sync_account_balance(api_service, bank_connection)
      
      # Sync transactions (last 90 days)
      sync_transactions(api_service, bank_connection)
      
      # Update financial profile
      update_financial_profile(bank_connection.user)
      
      bank_connection.update!(last_synced_at: Time.current)
      
    rescue OpenBankingError => e
      Rails.logger.error "Open Banking sync failed for connection #{bank_connection_id}: #{e.message}"
      
      if e.message.include?('Unauthorized')
        bank_connection.update!(status: 'expired')
      end
    end
  end

  private

  def refresh_token_if_needed(bank_connection)
    return unless bank_connection.needs_token_refresh?

    api_service = OpenBankingApiService.new
    response = api_service.refresh_token(bank_connection.refresh_token)
    
    bank_connection.update!(
      access_token: response['access_token'],
      refresh_token: response['refresh_token'],
      token_expires_at: Time.current + response['expires_in'].seconds
    )
  end

  def sync_account_balance(api_service, bank_connection)
    balance_data = api_service.get_account_balance(bank_connection.consent_id)
    
    bank_connection.account_balances.create!(
      current_balance: balance_data['current_balance'],
      available_balance: balance_data['available_balance'],
      ledger_balance: balance_data['ledger_balance'],
      balance_date: Time.current
    )
  end

  def sync_transactions(api_service, bank_connection)
    from_date = bank_connection.last_synced_at || 90.days.ago
    to_date = Time.current
    
    transactions_data = api_service.get_transactions(
      bank_connection.consent_id, 
      from_date, 
      to_date
    )
    
    transactions_data['transactions'].each do |txn_data|
      next if bank_connection.transactions.exists?(transaction_id: txn_data['id'])
      
      bank_connection.transactions.create!(
        transaction_id: txn_data['id'],
        transaction_type: txn_data['type'],
        amount: txn_data['amount'],
        currency: txn_data['currency'],
        description: txn_data['description'],
        category: categorize_transaction(txn_data['description']),
        merchant_name: txn_data['merchant_name'],
        metadata: txn_data['metadata'],
        transaction_date: Date.parse(txn_data['date'])
      )
    end
  end

  def update_financial_profile(user)
    FinancialProfileUpdateJob.perform_async(user.id)
  end

  def categorize_transaction(description)
    # Simple categorization logic - can be enhanced with ML
    case description.downcase
    when /salary|wage|payroll/
      'salary'
    when /transfer|deposit/
      'transfer'
    when /grocery|supermarket|food/
      'groceries'
    when /fuel|petrol|gas/
      'transportation'
    when /utility|electricity|water|phone/
      'utilities'
    when /rent|mortgage/
      'housing'
    when /medical|hospital|pharmacy/
      'healthcare'
    when /school|education|tuition/
      'education'
    else
      'others'
    end
  end
end