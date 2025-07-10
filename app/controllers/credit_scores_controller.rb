# app/controllers/credit_scores_controller.rb
class CreditScoresController < ApplicationController
    before_action :authenticate_user!
    
    def index
      @credit_scores = current_user.credit_scores.recent.limit(10)
      @latest_score = @credit_scores.first
      @score_history = @credit_scores.last_6_months
    end
    
    def show
      @credit_score = current_user.credit_scores.find(params[:id])
    end
    
    def calculate
        # Check if user has any bank connections
        unless current_user.bank_connections.active.any?
          redirect_to bank_connections_path, alert: 'Please connect at least one bank account to calculate your credit score.'
          return
        end
        
        begin
          # Check available transaction data
          total_transactions = current_user.bank_connections.joins(:transactions).count
          
          Rails.logger.info "User #{current_user.id} has #{total_transactions} transactions available"
          
          # Handle insufficient data scenarios
          if total_transactions < 10
            handle_insufficient_data
            return
          end
          
          # Calculate credit score using existing transaction data
          score_result = CreditScoringService.new(current_user).calculate_score
          
          if score_result[:success]
            redirect_to credit_score_path, notice: 'Credit score calculated successfully!'
          else
            redirect_to dashboard_path, alert: "Credit score calculation failed: #{score_result[:error]}"
          end
          
        rescue => e
          Rails.logger.error "Credit score calculation error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          redirect_to dashboard_path, alert: 'An error occurred while calculating your credit score. Please try again later.'
        end
    end
      
    
    def refresh
        # Force refresh transaction data and recalculate
        begin
          current_user.bank_connections.active.each do |connection|
            # Schedule sync job with force refresh
            OpenBankingDataSyncJob.perform_later(connection.id, true)
          end
          
          redirect_to dashboard_path, notice: 'Data refresh initiated. Your credit score will be updated shortly.'
          
        rescue => e
          Rails.logger.error "Data refresh error: #{e.message}"
          redirect_to dashboard_path, alert: 'Failed to refresh data. Please try again later.'
        end
    end

    private
  
    def fetch_fresh_transaction_data
        all_financial_data = {
          accounts: [],
          all_transactions: [],
          total_accounts: 0,
          total_transactions: 0
        }
        
        current_user.bank_connections.active.each do |connection|
          begin
            # Use your existing api_service method
            financial_data = connection.api_service.get_comprehensive_financial_data(connection, 6)
            save_transactions_to_db(connection, financial_data)

            # Combine data from all connections
            all_financial_data[:accounts].concat(financial_data[:accounts])
            all_financial_data[:all_transactions].concat(financial_data[:all_transactions])
            all_financial_data[:total_accounts] += financial_data[:total_accounts]
            
          rescue => e
            Rails.logger.error "Failed to fetch data from connection #{connection.id}: #{e.message}"
            # Continue with other connections
          end
        end
        
        all_financial_data[:total_transactions] = all_financial_data[:all_transactions].length
        
        Rails.logger.info "Fetched #{all_financial_data[:total_transactions]} transactions from #{all_financial_data[:total_accounts]} accounts"
        
        all_financial_data
    end

    def save_transactions_to_db(connection, financial_data)
        ActiveRecord::Base.transaction do
          # Save account balances
          financial_data[:accounts].each do |account_data|
            connection.account_balances.create!(
              account_number: account_data['account_number'],
              current_balance: account_data['current_balance'] || 0,
              available_balance: account_data['available_balance'] || account_data['current_balance'] || 0,
              ledger_balance: account_data['ledger_balance'] || account_data['current_balance'] || 0,
              balance_date: Time.current
            )
          end
          
          # Save transactions
          saved_count = 0
          financial_data[:all_transactions].each do |txn_data|
            next if connection.transactions.exists?(external_transaction_id: txn_data['id'])
            
            begin
              connection.transactions.create!(
                transaction_id: txn_data['id'],           # Use transaction_id instead of external_transaction_id
                external_transaction_id: txn_data['id'],  # Keep this for reference
                account_number: txn_data['account_number'],
                amount: parse_transaction_amount(txn_data),
                transaction_type: map_transaction_type(txn_data),
                description: txn_data['narration'] || 'Unknown transaction',
                reference: txn_data['reference'],
                transaction_date: parse_transaction_date(txn_data),
                balance_after: txn_data['balance_after'].to_f
              )
              
              saved_count += 1
            rescue => e
              Rails.logger.error "Failed to save transaction #{txn_data['id']}: #{e.message}"
              # Continue with other transactions
            end
          end
          
          connection.update!(last_synced_at: Time.current)
          Rails.logger.info "Saved #{saved_count} new transactions for connection #{connection.id}"
        end
      rescue => e
        Rails.logger.error "Failed to save transactions for connection #{connection.id}: #{e.message}"
    end
      
      # Also update the map_transaction_type method to match your validation:
    def map_transaction_type(txn_data)
        case txn_data['debit_credit']&.upcase
        when 'DEBIT'
            'debit'
        when 'CREDIT'
            'credit'
        else
            'debit' # Default fallback
        end
    end
      
    def parse_transaction_date(txn_data)
        date_string = txn_data['transaction_time'] || txn_data['value_date']
        return Date.current unless date_string
        
        begin
            if date_string.include?('T')
            DateTime.parse(date_string).to_date
            else
            Date.parse(date_string)
            end
        rescue
            Date.current
        end
    end

    def parse_transaction_amount(txn_data)
        amount = txn_data['amount'].to_f
        # Make debits negative, credits positive
        txn_data['debit_credit'] == 'DEBIT' ? -amount.abs : amount.abs
    end
    
    
    def calculate_credit_score_with_api_data(financial_data)
      # Create a temporary credit analysis using the fresh API data
      analysis_service = ApiCreditAnalysisService.new(current_user, financial_data)
      analysis_result = analysis_service.perform_analysis

      risk_level = case analysis_result[:score]
            when 750..850 then 'Excellent'
            when 650..749 then 'Good'
            when 550..649 then 'Poor'
        else 'Very Poor'
        end

      # Create and save the credit score
      credit_score = current_user.credit_scores.create!(
        score: analysis_result[:score],
        risk_level: risk_level,  # Add this line
        grade: analysis_result[:grade],
        analysis_data: analysis_result[:analysis_data].to_json,
        calculated_at: Time.current
      )
      
      credit_score
    end

    def handle_insufficient_data
        total_transactions = current_user.bank_connections.joins(:transactions).count
        
        Rails.logger.info "Insufficient transaction data (#{total_transactions}), checking if we should generate mock data or fetch from API"
        
        if Rails.env.development? || Rails.env.test?
          # In development, offer to generate mock data
          if params[:generate_mock_data] == 'true'
            generate_mock_data_and_calculate
            return
          else
            redirect_to dashboard_path, alert: insufficient_data_message_with_mock_option
            return
          end
        end
        
        # In production or if not using mock data, try to fetch fresh data
        if should_attempt_fresh_fetch?
          attempt_fresh_data_fetch
        else
          redirect_to dashboard_path, alert: insufficient_data_message
        end
    end
      
    def generate_mock_data_and_calculate
        begin
          # Generate mock data for all active connections
          current_user.bank_connections.active.each do |connection|
            MockDataService.generate_mock_transactions(connection, 6)
          end
          
          # Now calculate credit score with mock data
          score_result = CreditScoringService.new(current_user).calculate_score
          
          if score_result[:success]
            redirect_to credit_score_path, notice: 'Credit score calculated with demo data!'
          else
            redirect_to dashboard_path, alert: "Credit score calculation failed: #{score_result[:error]}"
          end
          
        rescue => e
          Rails.logger.error "Mock data generation error: #{e.message}"
          redirect_to dashboard_path, alert: 'Failed to generate demo data. Please try again.'
        end
    end
      
    def should_attempt_fresh_fetch?
        # Only attempt fresh fetch if we haven't tried recently
        last_sync = current_user.bank_connections.active.maximum(:last_synced_at)
        last_sync.nil? || last_sync < 30.minutes.ago
    end
      
    def attempt_fresh_data_fetch
        Rails.logger.info "Attempting to fetch fresh transaction data..."
        
        fetched_count = 0
        failed_count = 0
        
        current_user.bank_connections.active.each do |connection|
          begin
            # Only try if connection hasn't been synced recently
            if connection.last_synced_at.nil? || connection.last_synced_at < 30.minutes.ago
              Rails.logger.info "Attempting sync for connection #{connection.id}"
              
              # Try immediate sync with rate limiting
              RateLimitHandler.with_rate_limiting(context: "manual_sync_#{connection.id}") do
                sync_connection_data(connection)
                fetched_count += 1
              end
            else
              Rails.logger.info "Skipping connection #{connection.id} - recently synced"
            end
            
          rescue OpenBankingApiService::OpenBankingError => e
            Rails.logger.warn "Failed to fetch data from connection #{connection.id}: #{e.message}"
            failed_count += 1
            
            # Mark connection with appropriate status
            case e.status_code
            when 401
              connection.update!(status: 'expired', error_message: e.message)
            when 403
              connection.update!(status: 'revoked', error_message: e.message)
            when 429
              # Don't mark as error for rate limits
              Rails.logger.info "Rate limited for connection #{connection.id}, will retry later"
            end
          rescue => e
            Rails.logger.error "Unexpected error fetching data from connection #{connection.id}: #{e.message}"
            failed_count += 1
          end
        end
        
        Rails.logger.info "Fetched #{fetched_count} connections, failed #{failed_count}"
        
        # Check if we have enough data now
        total_transactions = current_user.bank_connections.joins(:transactions).count
        
        if total_transactions >= 10
          # We have enough data now, calculate score
          score_result = CreditScoringService.new(current_user).calculate_score
          
          if score_result[:success]
            redirect_to credit_score_path, notice: 'Credit score calculated successfully!'
          else
            redirect_to dashboard_path, alert: "Credit score calculation failed: #{score_result[:error]}"
          end
        else
          redirect_to dashboard_path, alert: "Insufficient transaction data (#{total_transactions} found). #{fetch_failure_message(failed_count)}"
        end
    end

    def sync_connection_data(connection)
        return unless connection.active?
        
        api_service = connection.api_service
        
        # Get accounts
        accounts_data = api_service.get_accounts
        return unless accounts_data&.dig('data', 'accounts')
        
        # Process each account
        accounts_data['data']['accounts'].each do |account_data|
          account_number = account_data['account_number']
          
          # Get recent transactions (last 90 days)
          from_date = 90.days.ago
          to_date = Time.current
          
          transactions_data = api_service.get_account_transactions(account_number, from_date, to_date)
          
          if transactions_data&.dig('data', 'transactions')
            sync_transactions_for_account(connection, account_number, transactions_data['data']['transactions'])
          end
          
          # Add delay between accounts
          sleep(2)
        end
        
        connection.update!(last_synced_at: Time.current)
    end

    def sync_transactions_for_account(connection, account_number, transactions)
        return if transactions.empty?
        
        new_transactions = []
        
        transactions.each do |txn_data|
          next if connection.transactions.exists?(external_transaction_id: txn_data['id'])
          
          new_transactions << {
            external_transaction_id: txn_data['id'],
            account_number: account_number,
            amount: (txn_data['amount'] || 0).to_f.round(2),
            transaction_type: txn_data['type'] || 'UNKNOWN',
            description: txn_data['description'] || '',
            reference: txn_data['reference'] || '',
            transaction_date: parse_date(txn_data['date']),
            balance_after: (txn_data['balance_after'] || 0).to_f.round(2),
            metadata: txn_data,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        
        if new_transactions.any?
          connection.transactions.insert_all(new_transactions)
          Rails.logger.info "Inserted #{new_transactions.size} transactions for account #{account_number}"
        end
    end
      
    def parse_date(date_string)
        return Time.current.to_date if date_string.nil?
        Date.parse(date_string.to_s) rescue Time.current.to_date
    end
      
    def insufficient_data_message
        total = current_user.bank_connections.joins(:transactions).count
        "Insufficient transaction data (#{total} found). Please ensure your connected accounts have recent transaction history."
    end

    def insufficient_data_message_with_mock_option
        total = current_user.bank_connections.joins(:transactions).count
        message = "Insufficient transaction data (#{total} found). "
        message += "Since you're in development mode, you can <a href='#{calculate_credit_scores_path}?generate_mock_data=true' class='text-blue-600 underline'>generate demo data</a> to test the credit scoring feature."
        message.html_safe
    end
      
    def fetch_failure_message(failed_count)
        if failed_count > 0
          "#{failed_count} bank connection(s) failed to sync. Please check your bank connections and try again."
        else
          "Please ensure your bank accounts have transaction history and try again later."
        end
    end
      
end
  