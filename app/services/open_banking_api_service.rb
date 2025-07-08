# app/services/open_banking_api_service.rb
class OpenBankingApiService
    include HTTParty
    
    class OpenBankingError < StandardError
      attr_reader :status_code, :error_code, :error_message
      
      def initialize(message, status_code = nil, error_code = nil, error_message = nil)
        @status_code = status_code
        @error_code = error_code
        @error_message = error_message
        super(message)
      end
    end
    
    def initialize(access_token = nil, base_url = nil)
      @access_token = access_token
      @base_url = base_url || Rails.application.credentials.open_banking[:base_url]
      @client_id = Rails.application.credentials.open_banking[:client_id]
      @client_secret = Rails.application.credentials.open_banking[:client_secret]
      @connection_id = Rails.application.credentials.open_banking[:connection_id]
      
      self.class.base_uri(@base_url)
    end
    
    # OAuth2 Device Code Flow
    def initiate_consent_request(scopes, account_number = nil, target_connection_id = nil)
      body = {
        client_id: @client_id,
        scope: scopes.join(' '),
        target_connection_id: target_connection_id || @connection_id
      }
      
      body[:account_number] = account_number if account_number
      
      response = self.class.post('/oauth2/device/code', {
        headers: basic_auth_headers,
        body: URI.encode_www_form(body)
      })
      
      handle_response(response)
    end
    
    def get_access_token(device_code, user_code, user_input = nil)
      body = {
        client_id: @client_id,
        grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
        device_code: device_code,
        user_code: user_code
      }
      
      body[:user_input] = user_input if user_input
      
      response = self.class.post('/oauth2/token', {
        headers: basic_auth_headers,
        body: URI.encode_www_form(body)
      })
      
      handle_response(response)
    end
    
    def refresh_token(refresh_token)
      body = {
        client_id: @client_id,
        grant_type: 'refresh_token',
        refresh_token: refresh_token
      }
      
      response = self.class.post('/oauth2/token', {
        headers: basic_auth_headers,
        body: URI.encode_www_form(body)
      })
      
      handle_response(response)
    end
    
    def revoke_token(token, token_type_hint = 'access_token')
      body = {
        client_id: @client_id,
        token: token,
        token_type_hint: token_type_hint
      }
      
      response = self.class.post('/oauth2/revoke', {
        headers: basic_auth_headers,
        body: URI.encode_www_form(body)
      })
      
      handle_response(response)
    end
    
    # Discovery Endpoints
    def discover_services
      response = self.class.get('/discover', {
        headers: basic_auth_headers
      })
      
      handle_response(response)
    end
    
    def discover_connection(connection_id = nil)
      conn_id = connection_id || @connection_id
      response = self.class.get("/discover/#{conn_id}", {
        headers: basic_auth_headers
      })
      
      handle_response(response)
    end
    
    # Meta Information
    def get_branches
      response = self.class.get('/meta/branches', {
        headers: basic_auth_headers
      })
      
      handle_response(response)
    end
    
    def get_atms
      response = self.class.get('/meta/atms', {
        headers: basic_auth_headers
      })
      
      handle_response(response)
    end
    
    def get_pos_terminals
      response = self.class.get('/meta/pos', {
        headers: basic_auth_headers
      })
      
      handle_response(response)
    end
    
    def get_agents
      response = self.class.get('/meta/agents', {
        headers: basic_auth_headers
      })
      
      handle_response(response)
    end
    
    # Health Check
    def health_check(scope, from_date = nil, to_date = nil)
      params = {}
      params[:from] = from_date.strftime('%Y-%m-%d') if from_date
      params[:to] = to_date.strftime('%Y-%m-%d') if to_date
      
      query_string = params.any? ? "?#{URI.encode_www_form(params)}" : ""
      
      response = self.class.get("/health/#{scope}/#{query_string}", {
        headers: basic_auth_headers
      })
      
      handle_response(response)
    end
    
    # Customer Management
    def get_customers
      response = self.class.get('/customers', {
        headers: bearer_token_headers
      })
      
      handle_response(response)
    end
    
    def create_customer(customer_data)
      response = self.class.post('/customers', {
        headers: bearer_token_headers,
        body: customer_data.to_json
      })
      
      handle_response(response)
    end
    
    def update_customer(customer_id, customer_data)
      response = self.class.patch("/customers/#{customer_id}", {
        headers: bearer_token_headers,
        body: customer_data.to_json
      })
      
      handle_response(response)
    end
    
    # Account Management
    def get_accounts
      response = self.class.get('/accounts', {
        headers: bearer_token_headers
      })
      
      handle_response(response)
    end
    
    def get_account_balance(account_number)
      response = self.class.get("/accounts/#{account_number}/balance", {
        headers: bearer_token_headers
      })
      
      handle_response(response)
    end
    
    def get_account_transactions(account_number, from_date = nil, to_date = nil, limit = 100)
      params = { limit: limit }
      params[:from] = from_date.strftime('%Y-%m-%d') if from_date
      params[:to] = to_date.strftime('%Y-%m-%d') if to_date
      
      query_string = "?#{URI.encode_www_form(params)}"
      
      response = self.class.get("/accounts/#{account_number}/transactions#{query_string}", {
        headers: bearer_token_headers
      })
      
      handle_response(response)
    end
    
    def create_account_hold(account_number, hold_data)
      response = self.class.post("/accounts/#{account_number}/holds", {
        headers: bearer_token_headers,
        body: hold_data.to_json
      })
      
      handle_response(response)
    end
    
    def release_account_hold(account_number, hold_reference, status = 'INACTIVE')
      body = {
        status: status,
        custom_properties: []
      }
      
      response = self.class.patch("/accounts/#{account_number}/holds/#{hold_reference}", {
        headers: bearer_token_headers,
        body: body.to_json
      })
      
      handle_response(response)
    end
    
    # Transfers
    def initiate_transfer_enquiry(destination_bank_code, destination_account_number, custom_properties = [])
      body = {
        destination_bank_code: destination_bank_code,
        destination_account_number: destination_account_number,
        custom_properties: custom_properties
      }
      
      response = self.class.post('/transactions/enquiry', {
        headers: bearer_token_headers,
        body: body.to_json
      })
      
      handle_response(response)
    end
    
    def initiate_transfer(transfer_data)
      response = self.class.post('/transactions/transfer', {
        headers: bearer_token_headers,
        body: transfer_data.to_json
      })
      
      handle_response(response)
    end
    
    def get_transfer_status(reference)
      response = self.class.get("/transactions/transfer/#{reference}", {
        headers: bearer_token_headers
      })
      
      handle_response(response)
    end
    
    # Bill Payments
    def get_bill_categories
      response = self.class.get('/bills/categories', {
        headers: bearer_token_headers
      })
      
      handle_response(response)
    end
    
    def get_billers(category_id)
      response = self.class.get("/bills/#{category_id}/billers", {
        headers: bearer_token_headers
      })
      
      handle_response(response)
    end
    
    def validate_bill_reference(category_id, biller_id, bill_reference)
      response = self.class.get("/bills/#{category_id}/billers/#{biller_id}/reference/#{bill_reference}", {
        headers: bearer_token_headers
      })
      
      handle_response(response)
    end
    
    def pay_bill(category_id, biller_id, bill_reference, payment_data)
      response = self.class.post("/bills/#{category_id}/billers/#{biller_id}/reference/#{bill_reference}", {
        headers: bearer_token_headers,
        body: payment_data.to_json
      })
      
      handle_response(response)
    end
    
    private
    
    def basic_auth_headers
      idempotency_key = generate_idempotency_key
      signature = generate_signature(@client_secret, idempotency_key)
      
      {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'Authorization' => basic_auth_string(@client_id, @client_secret),
        'connection_id' => @connection_id,
        'idempotency_key' => idempotency_key,
        'signature' => signature
      }
    end
    
    def bearer_token_headers
      raise OpenBankingError.new('Access token required') unless @access_token
      
      idempotency_key = generate_idempotency_key
      signature = generate_signature(@client_secret, idempotency_key, @access_token)
      
      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@access_token}",
        'idempotency_key' => idempotency_key,
        'signature' => signature
      }
      
      # Add consent token if available
      if @consent_token
        headers['consent_token'] = encrypt_consent_token(@consent_token)
      end
      
      headers
    end
    
    def basic_auth_string(username, password)
      "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
    end
    
    def generate_idempotency_key
      "#{Time.current.to_i}#{SecureRandom.hex(8)}"
    end
    
    def generate_signature(client_secret, idempotency_key, bearer_token = nil)
      signature_string = "#{client_secret};#{idempotency_key}"
      signature_string += ";#{bearer_token}" if bearer_token
      
      "SHA-256(#{Digest::SHA256.hexdigest(signature_string)})"
    end
    
    def encrypt_consent_token(consent_token)
      return nil unless consent_token
      
      # AES-256-CBC encryption with SHA-256 of CLIENT_SECRET as key
      cipher = OpenSSL::Cipher.new('AES-256-CBC')
      cipher.encrypt
      
      key = Digest::SHA256.digest(@client_secret)
      cipher.key = key
      
      iv = cipher.random_iv
      encrypted = cipher.update(consent_token) + cipher.final
      
      "AES-256-CBC(#{Base64.strict_encode64(iv + encrypted)})"
    end
    
    def handle_response(response)
      case response.code
      when 200..299
        response.parsed_response
      when 400
        error_data = response.parsed_response
        raise OpenBankingError.new(
          "Bad Request: #{error_data['message'] || 'Invalid request'}",
          response.code,
          error_data['error_code'],
          error_data['message']
        )
      when 401
        raise OpenBankingError.new(
          "Unauthorized: Access token expired or invalid",
          response.code
        )
      when 403
        raise OpenBankingError.new(
          "Forbidden: Insufficient permissions",
          response.code
        )
      when 404
        raise OpenBankingError.new(
          "Not Found: Resource not found",
          response.code
        )
      when 429
        raise OpenBankingError.new(
          "Rate Limit Exceeded: Too many requests",
          response.code
        )
      when 500..599
        raise OpenBankingError.new(
          "Server Error: #{response.code}",
          response.code
        )
      else
        raise OpenBankingError.new(
          "Unexpected response: #{response.code}",
          response.code
        )
      end
    end
end