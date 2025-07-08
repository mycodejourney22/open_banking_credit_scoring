# app/controllers/bank_connections_controller.rb
class BankConnectionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_bank_connection, only: [:show, :destroy, :refresh, :revoke, :poll_status]
    
    def index
      @bank_connections = current_user.bank_connections.includes(:account_balances)
      
      render json: {
        status: 'success',
        data: {
          connections: @bank_connections.map do |connection|
            {
              id: connection.id,
              bank_name: connection.bank_name,
              status: connection.status,
              account_number: connection.account_number,
              last_synced_at: connection.last_synced_at,
              created_at: connection.created_at,
              needs_refresh: connection.needs_token_refresh?,
              current_balance: connection.account_balances.order(:created_at).last&.current_balance
            }
          end
        }
      }
    end
    
    def show
      render json: {
        status: 'success',
        data: {
          connection: {
            id: @bank_connection.id,
            bank_name: @bank_connection.bank_name,
            status: @bank_connection.status,
            account_number: @bank_connection.account_number,
            scopes: @bank_connection.scopes,
            last_synced_at: @bank_connection.last_synced_at,
            token_expires_at: @bank_connection.token_expires_at,
            consent_expires_at: @bank_connection.consent_expires_at,
            created_at: @bank_connection.created_at
          }
        }
      }
    end
    
    def create
      # Step 1: Initiate consent request
      api_service = OpenBankingApiService.new
      
      begin
        # Define required scopes
        scopes = [
          'accounts.list.readonly',
          'accounts.balance.readonly', 
          'accounts.transactions.readonly',
          'transfers.initiate'
        ]
        
        # Add bill payment scopes if requested
        if params[:include_bill_payments]
          scopes += ['bills.list.readonly', 'bills.pay']
        end
        
        response = api_service.initiate_consent_request(
          scopes,
          params[:account_number],
          params[:target_connection_id]
        )
        
        # Check for existing connection with same bank and account
        bank_code = get_bank_code(params[:bank_name])
        existing_connection = current_user.bank_connections.find_by(
          bank_code: bank_code,
          account_number: params[:account_number]
        )
        
        if existing_connection
          return render json: {
            status: 'error',
            message: "This #{params[:bank_name]} account (#{params[:account_number]}) is already connected",
            data: {
              connection_id: existing_connection.id,
              status: existing_connection.status
            }
          }, status: :unprocessable_entity
        end
        
        # Create bank connection record
        # Generate unique connection_id for each connection
        unique_connection_id = "CONN#{SecureRandom.hex(5).upcase}"
        
        @bank_connection = current_user.bank_connections.create!(
          bank_name: params[:bank_name],
          bank_code: bank_code,
          connection_id: unique_connection_id,
          account_number: params[:account_number],
          device_code: response['device_code'],
          user_code: response['user_code'],
          verification_uri: response['verification_uri'],
          consent_expires_at: Time.current + response['expires_in'].seconds,
          polling_interval: response['interval'],
          scopes: scopes,
          status: 'pending'
        )
        
        render json: {
          status: 'success',
          message: 'Consent request initiated successfully',
          data: {
            connection_id: @bank_connection.id,
            user_code: response['user_code'],
            verification_uri: response['verification_uri'],
            expires_in: response['expires_in'],
            polling_interval: response['interval'],
            consent_message: response.dig('obn_custom_metadata', 'consent_message'),
            consent_validation_method: response.dig('obn_custom_metadata', 'consent_validation_method')
          }
        }
        
      rescue OpenBankingApiService::OpenBankingError => e
        render json: {
          status: 'error',
          message: "Failed to initiate consent request: #{e.message}",
          error_code: e.error_code
        }, status: :unprocessable_entity
      end
    end
    
    def poll_status
      # Step 2: Poll for consent approval and get access token
      return render_error('Connection not in pending state', :bad_request) unless @bank_connection.consent_pending?
      return render_error('Consent request expired', :gone) if @bank_connection.consent_expired?
      
      begin
        api_service = OpenBankingApiService.new
        
        response = api_service.get_access_token(
          @bank_connection.device_code,
          @bank_connection.user_code,
          params[:user_input]
        )
        
        # Decode JWT to extract consent token
        jwt_payload = decode_jwt_payload(response['access_token'])
        consent_token = decrypt_consent_token(jwt_payload['jti']) if jwt_payload['jti']
        
        @bank_connection.update!(
          encrypted_access_token: response['access_token'],
          encrypted_refresh_token: response['refresh_token'],
          consent_token: consent_token,
          token_expires_at: Time.current + response['expires_in'].seconds,
          scopes: response['scope']&.split(' ') || [],
          status: 'active'
        )
        
        # Schedule immediate sync
        OpenBankingDataSyncJob.perform_later(@bank_connection.id)
        
        render json: {
          status: 'success',
          message: 'Bank connection established successfully',
          data: {
            connection_id: @bank_connection.id,
            status: @bank_connection.status,
            expires_in: response['expires_in'],
            scopes: @bank_connection.scopes
          }
        }
        
      rescue OpenBankingApiService::OpenBankingError => e
        # Handle specific OAuth errors
        case e.error_code
        when 'authorization_pending'
          render json: {
            status: 'pending',
            message: 'User has not yet completed authorization',
            data: {
              retry_after: @bank_connection.polling_interval
            }
          }
        when 'slow_down'
          render json: {
            status: 'pending',
            message: 'Polling too frequently, slow down',
            data: {
              retry_after: @bank_connection.polling_interval * 2
            }
          }
        when 'expired_token'
          @bank_connection.update!(status: 'expired')
          render_error('Consent request expired', :gone)
        when 'access_denied'
          @bank_connection.update!(status: 'revoked')
          render_error('User denied consent', :forbidden)
        else
          @bank_connection.update!(status: 'error', error_message: e.message)
          render_error("Authorization failed: #{e.message}", :unprocessable_entity)
        end
      end
    end
    
    def refresh
      if @bank_connection.refresh_access_token!
        render json: {
          status: 'success',
          message: 'Access token refreshed successfully',
          data: {
            connection_id: @bank_connection.id,
            status: @bank_connection.status,
            token_expires_at: @bank_connection.token_expires_at
          }
        }
      else
        render json: {
          status: 'error',
          message: 'Failed to refresh access token',
          data: {
            connection_id: @bank_connection.id,
            status: @bank_connection.status,
            error_message: @bank_connection.error_message
          }
        }, status: :unprocessable_entity
      end
    end
    
    def revoke
      @bank_connection.revoke_access!
      
      render json: {
        status: 'success',
        message: 'Bank connection revoked successfully',
        data: {
          connection_id: @bank_connection.id,
          status: @bank_connection.status
        }
      }
    end
    
    def destroy
      @bank_connection.revoke_access! if @bank_connection.active?
      @bank_connection.destroy!
      
      render json: {
        status: 'success',
        message: 'Bank connection deleted successfully'
      }
    end
    
    def sync
      @bank_connection = current_user.bank_connections.find(params[:id])
      
      return render_error('Connection not active', :bad_request) unless @bank_connection.active?
      
      begin
        # Refresh token if needed
        @bank_connection.refresh_access_token! if @bank_connection.needs_token_refresh?
        
        # Sync accounts and transactions
        @bank_connection.sync_accounts!
        @bank_connection.sync_transactions!(
          params[:account_number],
          params[:from_date]&.to_date,
          params[:to_date]&.to_date
        )
        
        render json: {
          status: 'success',
          message: 'Data synchronized successfully',
          data: {
            connection_id: @bank_connection.id,
            last_synced_at: @bank_connection.last_synced_at
          }
        }
        
      rescue OpenBankingApiService::OpenBankingError => e
        render_error("Sync failed: #{e.message}", :unprocessable_entity)
      end
    end
    
    # Bill Payment Methods
    def bill_categories
      @bank_connection = current_user.bank_connections.find(params[:id])
      return render_error('Connection not active', :bad_request) unless @bank_connection.active?
      
      begin
        categories = @bank_connection.api_service.get_bill_categories
        
        render json: {
          status: 'success',
          data: categories['data']
        }
      rescue OpenBankingApiService::OpenBankingError => e
        render_error("Failed to fetch bill categories: #{e.message}", :unprocessable_entity)
      end
    end
    
    def billers
      @bank_connection = current_user.bank_connections.find(params[:id])
      return render_error('Connection not active', :bad_request) unless @bank_connection.active?
      
      begin
        billers = @bank_connection.api_service.get_billers(params[:category_id])
        
        render json: {
          status: 'success',
          data: billers['data']
        }
      rescue OpenBankingApiService::OpenBankingError => e
        render_error("Failed to fetch billers: #{e.message}", :unprocessable_entity)
      end
    end
    
    def validate_bill
      @bank_connection = current_user.bank_connections.find(params[:id])
      return render_error('Connection not active', :bad_request) unless @bank_connection.active?
      
      begin
        validation = @bank_connection.api_service.validate_bill_reference(
          params[:category_id],
          params[:biller_id],
          params[:bill_reference]
        )
        
        render json: {
          status: 'success',
          data: validation['data']
        }
      rescue OpenBankingApiService::OpenBankingError => e
        render_error("Bill validation failed: #{e.message}", :unprocessable_entity)
      end
    end
    
    def pay_bill
      @bank_connection = current_user.bank_connections.find(params[:id])
      return render_error('Connection not active', :bad_request) unless @bank_connection.active?
      
      begin
        payment_data = {
          amount: params[:amount],
          source_account_number: params[:source_account_number],
          product_info: {
            category_id: params[:category_id],
            biller_id: params[:biller_id],
            product_id: params[:product_id]
          },
          payer_info: {
            name: params[:payer_name],
            email: params[:payer_email],
            phone: params[:payer_phone]
          },
          custom_properties: params[:custom_properties] || []
        }
        
        payment_result = @bank_connection.api_service.pay_bill(
          params[:category_id],
          params[:biller_id],
          params[:bill_reference],
          payment_data
        )
        
        # Store bill payment record
        bill_payment = @bank_connection.bill_payments.create!(
          category_id: params[:category_id],
          biller_id: params[:biller_id],
          bill_reference: params[:bill_reference],
          amount: params[:amount],
          source_account_number: params[:source_account_number],
          payer_name: params[:payer_name],
          payer_email: params[:payer_email],
          payer_phone: params[:payer_phone],
          external_reference: payment_result.dig('data', 'reference'),
          status: payment_result.dig('data', 'status') || 'PENDING',
          metadata: payment_result['data']
        )
        
        render json: {
          status: 'success',
          message: 'Bill payment initiated successfully',
          data: {
            payment_id: bill_payment.id,
            reference: payment_result.dig('data', 'reference'),
            status: payment_result.dig('data', 'status'),
            amount: params[:amount]
          }
        }
        
      rescue OpenBankingApiService::OpenBankingError => e
        render_error("Bill payment failed: #{e.message}", :unprocessable_entity)
      end
    end
    
    # Transfer Methods
    def transfer_enquiry
      @bank_connection = current_user.bank_connections.find(params[:id])
      return render_error('Connection not active', :bad_request) unless @bank_connection.active?
      
      begin
        enquiry_result = @bank_connection.api_service.initiate_transfer_enquiry(
          params[:destination_bank_code],
          params[:destination_account_number],
          params[:custom_properties] || []
        )
        
        render json: {
          status: 'success',
          data: enquiry_result['data']
        }
      rescue OpenBankingApiService::OpenBankingError => e
        render_error("Transfer enquiry failed: #{e.message}", :unprocessable_entity)
      end
    end
    
    def initiate_transfer
      @bank_connection = current_user.bank_connections.find(params[:id])
      return render_error('Connection not active', :bad_request) unless @bank_connection.active?
      
      begin
        transfer_data = {
          amount: params[:amount],
          source_account_number: params[:source_account_number],
          destination_bank_code: params[:destination_bank_code],
          destination_account_number: params[:destination_account_number],
          narration: params[:narration],
          reference: params[:reference],
          custom_properties: params[:custom_properties] || []
        }
        
        transfer_result = @bank_connection.api_service.initiate_transfer(transfer_data)
        
        render json: {
          status: 'success',
          message: 'Transfer initiated successfully',
          data: transfer_result['data']
        }
        
      rescue OpenBankingApiService::OpenBankingError => e
        render_error("Transfer initiation failed: #{e.message}", :unprocessable_entity)
      end
    end
    
    private
    
    def set_bank_connection
      @bank_connection = current_user.bank_connections.find(params[:id])
    end
    
    def render_error(message, status)
      render json: {
        status: 'error',
        message: message
      }, status: status
    end
    
    def get_bank_code(bank_name)
      # Nigerian bank codes mapping
      bank_codes = {
        'Access Bank' => '044',
        'GTBank' => '058',
        'Guaranty Trust Bank' => '058',
        'Zenith Bank' => '057',
        'First Bank' => '011',
        'First Bank of Nigeria' => '011',
        'UBA' => '033',
        'United Bank for Africa' => '033',
        'Fidelity Bank' => '070',
        'FCMB' => '214',
        'First City Monument Bank' => '214',
        'Sterling Bank' => '232',
        'Union Bank' => '032',
        'Wema Bank' => '035',
        'Polaris Bank' => '076',
        'Stanbic IBTC' => '221',
        'Stanbic IBTC Bank' => '221',
        'Heritage Bank' => '030',
        'Keystone Bank' => '082',
        'Unity Bank' => '215'
      }
      
      bank_codes[bank_name] || '999' # Default fallback code
    end
    
    def decode_jwt_payload(jwt_token)
      parts = jwt_token.split('.')
      return {} unless parts.length == 3
      
      payload = Base64.urlsafe_decode64(parts[1] + '==')
      JSON.parse(payload)
    rescue JSON::ParserError, ArgumentError
      {}
    end
    
    def decrypt_consent_token(encrypted_consent_token)
      return nil unless encrypted_consent_token
      
      encrypted_data = encrypted_consent_token.gsub(/^AES-256-CBC\(|\)$/, '')
      
      begin
        cipher = OpenSSL::Cipher.new('AES-256-CBC')
        cipher.decrypt
        
        client_secret = Rails.application.credentials.open_banking[:client_secret]
        key = Digest::SHA256.digest(client_secret)
        cipher.key = key
        
        encrypted_bytes = Base64.strict_decode64(encrypted_data)
        iv = encrypted_bytes[0..15]
        encrypted_content = encrypted_bytes[16..-1]
        
        cipher.iv = iv
        decrypted = cipher.update(encrypted_content) + cipher.final
        
        decrypted
      rescue => e
        Rails.logger.error "Failed to decrypt consent token: #{e.message}"
        nil
      end
    end
  end