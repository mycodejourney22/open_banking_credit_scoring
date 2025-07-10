class DirectApiSyncJob < ApplicationJob
  queue_as :high_priority
  
  def perform(user_id, purpose = 'credit_scoring')
    user = User.find(user_id)
    
    Rails.logger.info "Starting direct API sync for user #{user_id} (purpose: #{purpose})"
    
    begin
      total_synced = 0
      
      user.bank_connections.active.each do |connection|
        synced_count = sync_connection_data(connection, purpose)
        total_synced += synced_count
      end
      
      Rails.logger.info "Direct API sync completed for user #{user_id}: #{total_synced} transactions synced"
      
      # Optionally trigger credit score calculation if that was the purpose
      if purpose == 'credit_scoring' && total_synced >= 10
        CreditScoreCalculationJob.perform_later(user_id)
      end
      
    rescue => e
      Rails.logger.error "Direct API sync failed for user #{user_id}: #{e.message}"
      raise e
    end
  end
  
  private
  
  def sync_connection_data(connection, purpose)
    api_service = connection.api_service
    synced_count = 0
    
    begin
      # Get fresh financial data
      financial_data = api_service.get_comprehensive_financial_data(6)
      
      # Save accounts data
      financial_data[:accounts].each do |account_data|
        # Update or create account balance records
        connection.account_balances.create!(
          account_number: account_data['account_number'],
          current_balance: account_data['current_balance'],
          available_balance: account_data['available_balance'],
          ledger_balance: account_data['ledger_balance'] || account_data['current_balance'],
          balance_date: Time.current,
          metadata: account_data
        )
      end
      
      # Save transaction data
      financial_data[:all_transactions].each do |txn_data|
        next if connection.transactions.exists?(external_transaction_id: txn_data['id'])
        
        connection.transactions.create!(
          external_transaction_id: txn_data['id'],
          account_number: txn_data['account_number'],
          amount: txn_data['amount'].to_f,
          transaction_type: map_transaction_type(txn_data),
          description: txn_data['narration'] || 'Unknown transaction',
          reference: txn_data['reference'],
          transaction_date: parse_transaction_date(txn_data),
          balance_after: txn_data['balance_after'].to_f,
          metadata: txn_data
        )
        
        synced_count += 1
      end
      
      connection.update!(last_synced_at: Time.current)
      
    rescue OpenBankingApiService::OpenBankingError => e
      Rails.logger.error "API sync failed for connection #{connection.id}: #{e.message}"
      connection.handle_api_error(e)
    end
    
    synced_count
  end
  
  def map_transaction_type(txn_data)
    # Map API transaction types to your internal types
    case txn_data['transaction_type']&.upcase
    when 'WITHDRAWAL', 'DEBIT'
      'debit'
    when 'DEPOSIT', 'CREDIT'
      'credit'
    when 'TRANSFER'
      txn_data['debit_credit'] == 'DEBIT' ? 'transfer_out' : 'transfer_in'
    else
      txn_data['debit_credit']&.downcase || 'unknown'
    end
  end
  
  def parse_transaction_date(txn_data)
    date_string = txn_data['transaction_time'] || txn_data['value_date']
    return Date.current unless date_string
    
    begin
      if date_string.include?('T') # ISO datetime
        DateTime.parse(date_string).to_date
      else
        Date.parse(date_string)
      end
    rescue
      Date.current
    end
  end
end