# app/models/bank_connection.rb
class BankConnection < ApplicationRecord
    belongs_to :user
    has_many :account_balances, dependent: :destroy
    has_many :transactions, dependent: :destroy
    has_many :bill_payments, dependent: :destroy
    
    validates :bank_name, presence: true
    validates :connection_id, presence: true, uniqueness: { scope: :user_id }
    validates :status, inclusion: { in: %w[pending active expired revoked error] }
    
    # Temporarily disabled encryption - uncomment when keys are configured
    # encrypts :access_token, :refresh_token, :consent_token
    
    enum status: {
      pending: 'pending',
      active: 'active', 
      expired: 'expired',
      revoked: 'revoked',
      error: 'error'
    }
    
    scope :active, -> { where(status: 'active') }
    scope :needs_refresh, -> { where('token_expires_at < ?', 1.hour.from_now) }
    
    def needs_token_refresh?
      return true unless token_expires_at
      token_expires_at < 1.hour.from_now
    end
    
    def token_expired?
      return true unless token_expires_at
      token_expires_at < Time.current
    end
    
    def consent_pending?
      status == 'pending' && device_code.present? && user_code.present?
    end
    
    def consent_expired?
      return false unless consent_expires_at
      consent_expires_at < Time.current
    end
    
    def api_service
        @api_service ||= OpenBankingApiService.new(encrypted_access_token)
    end
    
    def revoke_access!
      return unless encrypted_access_token.present?
      
      begin
        api_service.revoke_token(encrypted_access_token)
        update!(
          status: 'revoked',
          encrypted_access_token: nil,
          encrypted_refresh_token: nil,
          consent_token: nil,
          token_expires_at: nil
        )
      rescue OpenBankingApiService::OpenBankingError => e
        Rails.logger.error "Failed to revoke token for connection #{id}: #{e.message}"
        update!(status: 'error', error_message: e.message)
      end
    end
    
    def refresh_access_token!
      return false unless encrypted_refresh_token.present?
      
      begin
        response = api_service.refresh_token(encrypted_refresh_token)
        
        # Extract consent token from JWT
        jwt_payload = decode_jwt_payload(response['access_token'])
        consent_token = decrypt_consent_token(jwt_payload['jti']) if jwt_payload['jti']
        
        update!(
          encrypted_access_token: response['access_token'],
          encrypted_refresh_token: response['refresh_token'],
          consent_token: consent_token,
          token_expires_at: Time.current + response['expires_in'].seconds,
          scopes: response['scope']&.split(' ') || [],
          status: 'active'
        )
        
        true
      rescue OpenBankingApiService::OpenBankingError => e
        Rails.logger.error "Failed to refresh token for connection #{id}: #{e.message}"
        
        if e.status_code == 400 || e.status_code == 401
          update!(status: 'expired')
        else
          update!(status: 'error', error_message: e.message)
        end
        
        false
      end
    end

    def fetch_fresh_transactions(months_back = 6, save_to_db = false)
        return { transactions: [], accounts: [], total_count: 0 } unless active?
        
        begin
          financial_data = api_service.get_comprehensive_financial_data(months_back)
          
          if save_to_db
            save_fresh_data_to_db(financial_data)
          end
          
          {
            transactions: financial_data[:all_transactions],
            accounts: financial_data[:accounts],
            total_count: financial_data[:total_transactions],
            fetched_at: Time.current
          }
          
        rescue OpenBankingApiService::OpenBankingError => e
          Rails.logger.error "Failed to fetch fresh transactions for connection #{id}: #{e.message}"
          handle_api_error(e)
          { transactions: [], accounts: [], total_count: 0, error: e.message }
        end
    end

    def has_sufficient_transaction_data?(minimum_required = 10)
        # First check synced data
        synced_count = transactions.count
        return true if synced_count >= minimum_required
        
        # If not enough synced data, check what's available via API
        fresh_data = fetch_fresh_transactions(6, false)
        fresh_data[:total_count] >= minimum_required
    end

    def api_transaction_count(months_back = 6)
        return 0 unless active?
        
        begin
          # Just get the summary without fetching all transactions
          accounts_response = api_service.get_accounts
          accounts = accounts_response.dig('data', 'accounts') || []
          
          total_count = 0
          
          accounts.each do |account|
            account_number = account['account_number']
            
            # Get just the first page to check transaction summary
            transactions_response = api_service.get_account_transactions(
              account_number, 
              months_back.months.ago, 
              Time.current,
              1, # page
              1   # limit (just to get summary)
            )
            
            summary = transactions_response.dig('data', 'summary')
            if summary
              # Use the total count from summary
              total_count += (summary['total_debit_count'] || 0) + (summary['total_credit_count'] || 0)
            else
              # Fallback: get actual transactions count
              all_transactions = api_service.get_all_account_transactions(
                account_number, 
                months_back.months.ago, 
                Time.current
              )
              total_count += all_transactions.length
            end
          end
          
          total_count
          
        rescue OpenBankingApiService::OpenBankingError => e
          Rails.logger.error "Failed to get API transaction count for connection #{id}: #{e.message}"
          0
        end
    end
    
    # Force refresh token and retry operation
    def refresh_and_retry(&block)
        begin
            yield
        rescue OpenBankingApiService::OpenBankingError => e
            if e.status_code == 401 && can_refresh_token?
            Rails.logger.info "Access token expired for connection #{id}, attempting refresh..."
            
            if refresh_access_token!
                Rails.logger.info "Token refreshed successfully, retrying operation..."
                yield
            else
                raise e
            end
            else
            raise e
            end
        end
    end

    def test_api_connection
        return { success: false, error: 'Connection not active' } unless active?
        
        begin
          refresh_and_retry do
            accounts_response = api_service.get_accounts
            accounts = accounts_response.dig('data', 'accounts') || []
            
            {
              success: true,
              accounts_count: accounts.length,
              accounts: accounts.map { |a| { number: a['account_number'], name: a['account_name'] } },
              tested_at: Time.current
            }
          end
          
        rescue OpenBankingApiService::OpenBankingError => e
          {
            success: false,
            error: e.message,
            status_code: e.status_code,
            tested_at: Time.current
          }
        rescue => e
          {
            success: false,
            error: "Unexpected error: #{e.message}",
            tested_at: Time.current
          }
        end
    end
    
    def sync_accounts!
      return unless active?
      
      begin
        accounts_data = api_service.get_accounts
        
        # Store or update account information
        accounts_data['data']['accounts']&.each do |account_data|
          # Update or create account records
          # Implementation depends on your Account model structure
        end
        
        update!(last_synced_at: Time.current)
      rescue OpenBankingApiService::OpenBankingError => e
        handle_api_error(e)
      end
    end
    
    def sync_transactions!(account_number = nil, from_date = nil, to_date = nil)
      return unless active?
      
      begin
        if account_number
          sync_account_transactions(account_number, from_date, to_date)
        else
          # Sync all linked accounts
          # This would require getting accounts first
          accounts_data = api_service.get_accounts
          accounts_data['data']['accounts']&.each do |account|
            sync_account_transactions(account['account_number'], from_date, to_date)
          end
        end
        
        update!(last_synced_at: Time.current)
      rescue OpenBankingApiService::OpenBankingError => e
        handle_api_error(e)
      end
    end
    
    private
    
    def sync_account_transactions(account_number, from_date, to_date)
      from_date ||= last_synced_at || 90.days.ago
      to_date ||= Time.current
      
      transactions_data = api_service.get_account_transactions(
        account_number, 
        from_date, 
        to_date
      )
      
      transactions_data['data']['transactions']&.each do |txn_data|
        next if transactions.exists?(external_transaction_id: txn_data['id'])
        
        transactions.create!(
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
    
    def decode_jwt_payload(jwt_token)
      # Decode JWT without verification (since we trust the source)
      # In production, you should verify the JWT signature
      parts = jwt_token.split('.')
      return {} unless parts.length == 3
      
      payload = Base64.urlsafe_decode64(parts[1] + '==') # Add padding if needed
      JSON.parse(payload)
    rescue JSON::ParserError, ArgumentError
      {}
    end
    
    def decrypt_consent_token(encrypted_consent_token)
      return nil unless encrypted_consent_token
      
      # Remove the AES-256-CBC() wrapper if present
      encrypted_data = encrypted_consent_token.gsub(/^AES-256-CBC\(|\)$/, '')
      
      begin
        cipher = OpenSSL::Cipher.new('AES-256-CBC')
        cipher.decrypt
        
        # Use SHA-256 of client secret as key (matching API spec)
        client_secret = Rails.application.credentials.open_banking[:client_secret]
        key = Digest::SHA256.digest(client_secret)
        cipher.key = key
        
        encrypted_bytes = Base64.strict_decode64(encrypted_data)
        iv = encrypted_bytes[0..15] # First 16 bytes are IV
        encrypted_content = encrypted_bytes[16..-1]
        
        cipher.iv = iv
        decrypted = cipher.update(encrypted_content) + cipher.final
        
        decrypted
      rescue => e
        Rails.logger.error "Failed to decrypt consent token: #{e.message}"
        nil
      end
    end
    
    def handle_api_error(error)
      case error.status_code
      when 401
        update!(status: 'expired')
      when 403
        update!(status: 'revoked')
      else
        update!(status: 'error', error_message: error.message)
      end
      
      Rails.logger.error "API Error for connection #{id}: #{error.message}"
    end

    def save_fresh_data_to_db(financial_data)
        ActiveRecord::Base.transaction do
          # Save account balances
          financial_data[:accounts].each do |account_data|
            account_balances.create!(
              account_number: account_data['account_number'],
              current_balance: account_data['current_balance'],
              available_balance: account_data['available_balance'],
              ledger_balance: account_data['ledger_balance'] || account_data['current_balance'],
              balance_date: Time.current,
              metadata: account_data
            )
          end
          
          # Save transactions
          financial_data[:all_transactions].each do |txn_data|
            next if transactions.exists?(external_transaction_id: txn_data['id'])
            
            transactions.create!(
              external_transaction_id: txn_data['id'],
              account_number: txn_data['account_number'],
              amount: txn_data['amount'].to_f,
              transaction_type: map_api_transaction_type(txn_data),
              description: txn_data['narration'] || 'Unknown transaction',
              reference: txn_data['reference'],
              transaction_date: parse_api_transaction_date(txn_data),
              balance_after: txn_data['balance_after'].to_f,
              metadata: txn_data
            )
          end
          
          update!(last_synced_at: Time.current)
        end
      end
      
      def map_api_transaction_type(txn_data)
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
      
      def parse_api_transaction_date(txn_data)
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
      
      def can_refresh_token?
        encrypted_refresh_token.present? && 
        (token_expires_at.nil? || token_expires_at > 1.hour.from_now)
    end
end