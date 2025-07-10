# lib/tasks/open_banking.rake
namespace :open_banking do
    desc "Test API connection for a specific bank connection"
    task :test_connection, [:connection_id] => :environment do |t, args|
      connection_id = args[:connection_id]
      
      unless connection_id
        puts "Usage: rake open_banking:test_connection[CONNECTION_ID]"
        exit 1
      end
      
      connection = BankConnection.find(connection_id)
      api_service = connection.api_service
      
      puts "Testing connection #{connection_id} for user #{connection.user.email}"
      puts "Connection status: #{connection.status}"
      puts "Last synced: #{connection.last_synced_at || 'Never'}"
      puts ""
      
      begin
        # Test basic account access
        puts "1. Testing account access..."
        accounts_response = api_service.get_accounts
        accounts = accounts_response.dig('data', 'accounts') || []
        puts "✓ Found #{accounts.length} accounts"
        
        accounts.each_with_index do |account, index|
          puts "  Account #{index + 1}: #{account['account_number']} (#{account['account_name']})"
        end
        puts ""
        
        # Test transaction fetching for first account
        if accounts.any?
          first_account = accounts.first['account_number']
          puts "2. Testing transaction fetching for account #{first_account}..."
          
          transactions_response = api_service.get_account_transactions(
            first_account, 
            1.month.ago, 
            Time.current
          )
          
          transactions = transactions_response.dig('data', 'transactions') || []
          puts "✓ Found #{transactions.length} transactions in the last month"
          
          if transactions.any?
            puts "  Sample transactions:"
            transactions.first(3).each do |txn|
              puts "    #{txn['transaction_time']} | #{txn['debit_credit']} | ₦#{txn['amount']} | #{txn['narration']}"
            end
          end
          puts ""
          
          # Test comprehensive data fetch
          puts "3. Testing comprehensive data fetch..."
          financial_data = api_service.get_comprehensive_financial_data(3)
          puts "✓ Comprehensive fetch completed"
          puts "  Total accounts: #{financial_data[:total_accounts]}"
          puts "  Total transactions: #{financial_data[:total_transactions]}"
          puts ""
        end
        
        puts "✅ All tests passed! Connection is working properly."
        
      rescue OpenBankingApiService::OpenBankingError => e
        puts "❌ API Error: #{e.message} (Code: #{e.status_code})"
      rescue => e
        puts "❌ Unexpected Error: #{e.message}"
        puts e.backtrace.first(5)
      end
    end
    
    desc "Fetch fresh transaction data for credit scoring"
    task :fetch_for_credit_scoring, [:user_id] => :environment do |t, args|
      user_id = args[:user_id]
      
      unless user_id
        puts "Usage: rake open_banking:fetch_for_credit_scoring[USER_ID]"
        exit 1
      end
      
      user = User.find(user_id)
      puts "Fetching fresh transaction data for #{user.email}..."
      
      total_transactions = 0
      
      user.bank_connections.active.each do |connection|
        puts "\nProcessing connection #{connection.id}..."
        
        begin
          api_service = connection.api_service
          financial_data = api_service.get_comprehensive_financial_data(6)
          
          puts "  Accounts: #{financial_data[:total_accounts]}"
          puts "  Transactions: #{financial_data[:total_transactions]}"
          
          total_transactions += financial_data[:total_transactions]
          
          # Show transaction breakdown
          if financial_data[:all_transactions].any?
            credit_count = financial_data[:all_transactions].count { |t| t['debit_credit'] == 'CREDIT' }
            debit_count = financial_data[:all_transactions].count { |t| t['debit_credit'] == 'DEBIT' }
            
            puts "    Credits: #{credit_count}"
            puts "    Debits: #{debit_count}"
            
            # Show date range
            dates = financial_data[:all_transactions].map do |t|
              Date.parse(t['transaction_time'] || t['value_date'])
            end.sort
            
            puts "    Date range: #{dates.first} to #{dates.last}"
          end
          
        rescue OpenBankingApiService::OpenBankingError => e
          puts "  ❌ Error: #{e.message}"
        end
      end
      
      puts "\n📊 Summary:"
      puts "Total transactions found: #{total_transactions}"
      
      if total_transactions >= 10
        puts "✅ Sufficient data for credit scoring!"
        puts "\nTesting credit analysis..."
        
        begin
          # Test the credit analysis with fresh data
          all_financial_data = { accounts: [], all_transactions: [], total_accounts: 0, total_transactions: 0 }
          
          user.bank_connections.active.each do |connection|
            api_service = connection.api_service
            financial_data = api_service.get_comprehensive_financial_data(6)
            
            all_financial_data[:accounts].concat(financial_data[:accounts])
            all_financial_data[:all_transactions].concat(financial_data[:all_transactions])
            all_financial_data[:total_accounts] += financial_data[:total_accounts]
          end
          
          all_financial_data[:total_transactions] = all_financial_data[:all_transactions].length
          
          analysis_service = ApiCreditAnalysisService.new(user, all_financial_data)
          result = analysis_service.perform_analysis
          
          puts "\n🎯 Credit Analysis Results:"
          puts "Score: #{result[:score]}"
          puts "Grade: #{result[:grade]}"
          puts "Transaction Count: #{result[:analysis_data][:transaction_count]}"
          puts "Average Monthly Income: ₦#{result[:analysis_data][:income_analysis][:average_monthly_income].round(2)}"
          puts "Risk Factors: #{result[:analysis_data][:risk_factors].length}"
          
          if result[:analysis_data][:risk_factors].any?
            puts "  - #{result[:analysis_data][:risk_factors].join("\n  - ")}"
          end
          
        rescue => e
          puts "❌ Credit analysis failed: #{e.message}"
        end
      else
        puts "❌ Insufficient data for credit scoring (need at least 10 transactions)"
      end
    end
    
    desc "Test holds API functionality"
    task :test_holds, [:connection_id, :account_number] => :environment do |t, args|
      connection_id = args[:connection_id]
      account_number = args[:account_number]
      
      unless connection_id && account_number
        puts "Usage: rake open_banking:test_holds[CONNECTION_ID,ACCOUNT_NUMBER]"
        exit 1
      end
      
      connection = BankConnection.find(connection_id)
      api_service = connection.api_service
      
      puts "Testing holds functionality for account #{account_number}..."
      
      begin
        # Get existing holds
        puts "1. Getting existing holds..."
        holds_response = api_service.get_holds(account_number)
        existing_holds = holds_response.dig('data', 'holds') || []
        puts "✓ Found #{existing_holds.length} existing holds"
        
        existing_holds.each do |hold|
          puts "  Hold: #{hold['reference']} | ₦#{hold['amount']} | #{hold['status']}"
        end
        
        # Test placing a hold (small amount for testing)
        puts "\n2. Testing hold placement..."
        hold_data = {
          reference: "TEST_HOLD_#{SecureRandom.hex(8)}",
          amount: 100.00,
          narration: "Test hold for API verification",
          hold_start_timestamp: Date.current.strftime('%Y-%m-%d'),
          hold_end_timestamp: 1.week.from_now.strftime('%Y-%m-%d'),
          status: "ACTIVE"
        }
        
        hold_response = api_service.place_hold(account_number, hold_data)
        puts "✓ Hold placed successfully"
        puts "  Reference: #{hold_response.dig('data', 'reference')}"
        
        # Test releasing the hold
        puts "\n3. Testing hold release..."
        hold_reference = hold_response.dig('data', 'reference')
        
        if hold_reference
          release_response = api_service.release_hold(account_number, hold_reference)
          puts "✓ Hold released successfully"
        else
          puts "⚠️  Could not release hold - no reference returned"
        end
        
        puts "\n✅ Holds API test completed successfully!"
        
      rescue OpenBankingApiService::OpenBankingError => e
        puts "❌ Holds API Error: #{e.message} (Code: #{e.status_code})"
      rescue => e
        puts "❌ Unexpected Error: #{e.message}"
      end
    end
    
    desc "List all active bank connections"
    task :list_connections => :environment do
      connections = BankConnection.includes(:user).active
      
      puts "Active Bank Connections:"
      puts "=" * 50
      
      connections.each do |connection|
        puts "ID: #{connection.id}"
        puts "User: #{connection.user.email}"
        puts "Status: #{connection.status}"
        puts "Created: #{connection.created_at.strftime('%Y-%m-%d %H:%M')}"
        puts "Last Synced: #{connection.last_synced_at&.strftime('%Y-%m-%d %H:%M') || 'Never'}"
        puts "Transactions: #{connection.transactions.count}"
        puts "-" * 30
      end
      
      puts "\nTotal: #{connections.count} active connections"
    end
end