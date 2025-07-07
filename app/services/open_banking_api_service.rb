# app/services/open_banking_api_service.rb
class OpenBankingApiService
    include HTTParty
    
    base_uri Rails.application.config.open_banking_api_base_url
    
    def initialize(access_token = nil)
      @access_token = access_token
      @options = {
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      }
      @options[:headers]['Authorization'] = "Bearer #{@access_token}" if @access_token
    end
  
    def get_banks
      response = self.class.get('/banks', @options)
      handle_response(response)
    end
  
    def initiate_consent(bank_code, account_number, permissions = [])
      body = {
        bank_code: bank_code,
        account_number: account_number,
        permissions: permissions.presence || default_permissions,
        redirect_uri: Rails.application.routes.url_helpers.open_banking_callback_url
      }
      
      response = self.class.post('/consents', @options.merge(body: body.to_json))
      handle_response(response)
    end
  
    def exchange_code_for_token(consent_id, authorization_code)
      body = {
        client_id: Rails.application.config.open_banking_client_id,
        client_secret: Rails.application.config.open_banking_client_secret,
        consent_id: consent_id,
        code: authorization_code,
        grant_type: 'authorization_code'
      }
      
      response = self.class.post('/oauth/token', @options.merge(body: body.to_json))
      handle_response(response)
    end
  
    def get_account_info(account_id)
      response = self.class.get("/accounts/#{account_id}", @options)
      handle_response(response)
    end
  
    def get_account_balance(account_id)
      response = self.class.get("/accounts/#{account_id}/balance", @options)
      handle_response(response)
    end
  
    def get_transactions(account_id, from_date = nil, to_date = nil)
      query = {}
      query[:from_date] = from_date.iso8601 if from_date
      query[:to_date] = to_date.iso8601 if to_date
      
      url = "/accounts/#{account_id}/transactions"
      url += "?#{query.to_query}" if query.any?
      
      response = self.class.get(url, @options)
      handle_response(response)
    end
  
    def refresh_token(refresh_token)
      body = {
        client_id: Rails.application.config.open_banking_client_id,
        client_secret: Rails.application.config.open_banking_client_secret,
        refresh_token: refresh_token,
        grant_type: 'refresh_token'
      }
      
      response = self.class.post('/oauth/token', @options.merge(body: body.to_json))
      handle_response(response)
    end
  
    private
  
    def handle_response(response)
      case response.code
      when 200..299
        JSON.parse(response.body)
      when 401
        raise OpenBankingError, 'Unauthorized - invalid or expired token'
      when 403
        raise OpenBankingError, 'Forbidden - insufficient permissions'
      when 404
        raise OpenBankingError, 'Resource not found'
      when 429
        raise OpenBankingError, 'Rate limit exceeded'
      else
        raise OpenBankingError, "API Error: #{response.code} - #{response.body}"
      end
    end
  
    def default_permissions
      %w[
        ReadAccountsBasic
        ReadAccountsDetail
        ReadBalances
        ReadTransactionsBasic
        ReadTransactionsCredits
        ReadTransactionsDebits
        ReadTransactionsDetail
      ]
    end
end