# app/services/mock_data_service.rb (Fixed Version)
class MockDataService
    # Generate realistic mock transaction data for development/testing
    def self.generate_mock_transactions(bank_connection, months_back = 6)
      return if Rails.env.production? # Safety check
      
      Rails.logger.info "Generating mock data for bank connection #{bank_connection.id}"
      
      account_numbers = ['1234567890', '0987654321', '1122334455']
      
      account_numbers.each do |account_number|
        # Create account balance (with proper attributes)
        current_balance = rand(50_000..500_000)
        
        balance_record = bank_connection.account_balances.find_or_initialize_by(account_number: account_number)
        balance_record.assign_attributes(
          current_balance: current_balance,
          available_balance: current_balance - rand(0..10_000),
          ledger_balance: current_balance,
          balance_date: Time.current,
          currency: 'NGN'
        )
        
        # Only set metadata if the column exists
        if balance_record.respond_to?(:metadata=)
          balance_record.metadata = { 'mock_data' => true }
        end
        
        balance_record.save!
        
        # Generate transactions for the past X months
        start_date = months_back.months.ago
        running_balance = current_balance
        
        generate_salary_transactions(bank_connection, account_number, start_date, running_balance)
        generate_bill_payments(bank_connection, account_number, start_date)
        generate_shopping_transactions(bank_connection, account_number, start_date)
        generate_transfer_transactions(bank_connection, account_number, start_date)
      end
      
      total_transactions = bank_connection.transactions.count
      Rails.logger.info "Generated mock data: #{total_transactions} total transactions for connection #{bank_connection.id}"
    end
    
    private
    
    def self.generate_salary_transactions(bank_connection, account_number, start_date, running_balance)
      # Generate monthly salary credits
      (0..6).each do |month_offset|
        salary_date = start_date + month_offset.months + rand(25..30).days
        next if salary_date > Time.current
        
        salary_amount = rand(80_000..350_000)
        running_balance += salary_amount
        
        create_transaction(
          bank_connection,
          account_number,
          salary_amount,
          'credit',
          ['SALARY PAYMENT', 'MONTHLY SALARY', 'PAYROLL CREDIT'].sample,
          "SAL#{rand(100000..999999)}",
          salary_date,
          running_balance
        )
      end
    end
    
    def self.generate_bill_payments(bank_connection, account_number, start_date)
      bills = [
        { name: 'ELECTRICITY BILL', amount_range: 8_000..25_000 },
        { name: 'WATER BILL', amount_range: 3_000..8_000 },
        { name: 'INTERNET BILL', amount_range: 10_000..20_000 },
        { name: 'PHONE BILL', amount_range: 2_000..8_000 },
        { name: 'RENT PAYMENT', amount_range: 50_000..150_000 }
      ]
      
      current_date = start_date
      while current_date < Time.current
        bills.each do |bill|
          # Pay bills monthly with some randomness
          if rand < 0.8 # 80% chance of paying bill each month
            bill_date = current_date + rand(1..28).days
            next if bill_date > Time.current
            
            amount = rand(bill[:amount_range])
            
            create_transaction(
              bank_connection,
              account_number,
              -amount,
              'debit',
              bill[:name],
              "BILL#{rand(100000..999999)}",
              bill_date,
              rand(10_000..100_000) # Mock balance after
            )
          end
        end
        current_date += 1.month
      end
    end
    
    def self.generate_shopping_transactions(bank_connection, account_number, start_date)
      merchants = [
        'SHOPRITE', 'JUMIA', 'KONGA', 'SPAR', 'DOMINOS PIZZA',
        'UBER', 'BOLT', 'ZENITH BANK ATM', 'GTB ATM', 'POS WITHDRAWAL'
      ]
      
      # Generate 3-8 random transactions per month
      current_date = start_date
      while current_date < Time.current
        transactions_this_month = rand(3..8)
        
        transactions_this_month.times do
          txn_date = current_date + rand(0..30).days
          next if txn_date > Time.current
          
          amount = case merchants.sample
                  when /ATM|POS/ then rand(5_000..50_000)
                  when /UBER|BOLT/ then rand(800..5_000)
                  when /PIZZA/ then rand(3_000..15_000)
                  else rand(2_000..25_000)
                  end
          
          create_transaction(
            bank_connection,
            account_number,
            -amount,
            'debit',
            merchants.sample,
            "TXN#{rand(100000000..999999999)}",
            txn_date,
            rand(5_000..80_000) # Mock balance after
          )
        end
        
        current_date += 1.month
      end
    end
    
    def self.generate_transfer_transactions(bank_connection, account_number, start_date)
      # Generate some incoming transfers (friends, family, etc.)
      (0..12).each do |_|
        txn_date = start_date + rand(0..(Time.current - start_date).to_i).seconds
        next if txn_date > Time.current
        
        if rand < 0.3 # 30% chance of incoming transfer
          amount = rand(5_000..50_000)
          
          create_transaction(
            bank_connection,
            account_number,
            amount,
            'credit',
            ['TRANSFER FROM FRIEND', 'FAMILY SUPPORT', 'BUSINESS PAYMENT'].sample,
            "TRF#{rand(100000000..999999999)}",
            txn_date,
            rand(20_000..120_000)
          )
        end
      end
    end
    
    def self.create_transaction(bank_connection, account_number, amount, type, description, reference, date, balance_after)
      # Avoid duplicates
      return if bank_connection.transactions.exists?(
        account_number: account_number,
        reference: reference
      )
      
      transaction_attrs = {
        transaction_id: reference, # This was missing!
        external_transaction_id: "MOCK_#{reference}",
        account_number: account_number,
        amount: amount.round(2),
        transaction_type: type,
        description: description,
        reference: reference,
        transaction_date: date.to_date,
        balance_after: balance_after.round(2)
      }
      
      # Only set metadata if the column exists
      transaction = bank_connection.transactions.build(transaction_attrs)
      if transaction.respond_to?(:metadata=)
        transaction.metadata = {
          'mock_data' => true,
          'generated_at' => Time.current.iso8601
        }
      end
      
      transaction.save!
    rescue ActiveRecord::RecordNotUnique => e
      Rails.logger.warn "Duplicate transaction skipped: #{reference}"
      # Skip duplicates silently
    rescue => e
      Rails.logger.error "Failed to create transaction #{reference}: #{e.message}"
      raise e
    end
  end