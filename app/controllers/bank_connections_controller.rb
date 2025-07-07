# app/controllers/bank_connections_controller.rb
class BankConnectionsController < ApplicationController
    before_action :set_bank_connection, only: [:show, :destroy, :sync]

    def index
        @bank_connections = current_user.bank_connections.includes(:account_balances)
        @available_banks = OpenBankingApiService.new.get_banks
    end

    def show
        @transactions = @bank_connection.transactions.recent.limit(50)
        @balance_history = @bank_connection.account_balances.order(balance_date: :desc).limit(30)
    end

    def new
        @bank_connection = current_user.bank_connections.build
        @available_banks = OpenBankingApiService.new.get_banks
    end

    def create
        @bank_connection = current_user.bank_connections.build(bank_connection_params)
        
        begin
        # Initiate consent with Open Banking API
        api_service = OpenBankingApiService.new
        consent_response = api_service.initiate_consent(
            @bank_connection.bank_code,
            @bank_connection.account_number
        )
        
        @bank_connection.consent_id = consent_response['consent_id']
        
        if @bank_connection.save
            # Redirect to bank for authorization
            redirect_to consent_response['authorization_url']
        else
            @available_banks = api_service.get_banks
            render :new, status: :unprocessable_entity
        end
        rescue OpenBankingError => e
        flash.now[:alert] = e.message
        @available_banks = OpenBankingApiService.new.get_banks
        render :new, status: :unprocessable_entity
        end
    end

    def callback
        consent_id = params[:consent_id]
        authorization_code = params[:code]
        
        return redirect_to bank_connections_path, alert: 'Authorization failed' if authorization_code.blank?
        
        begin
        bank_connection = current_user.bank_connections.find_by(consent_id: consent_id)
        return redirect_to bank_connections_path, alert: 'Invalid consent' unless bank_connection
        
        # Exchange authorization code for access token
        api_service = OpenBankingApiService.new
        token_response = api_service.exchange_code_for_token(consent_id, authorization_code)
        
        bank_connection.update!(
            access_token: token_response['access_token'],
            refresh_token: token_response['refresh_token'],
            token_expires_at: Time.current + token_response['expires_in'].seconds,
            status: 'active'
        )
        
        # Start initial data sync
        bank_connection.sync_data!
        
        redirect_to bank_connection_path(bank_connection), notice: 'Bank account connected successfully!'
        rescue OpenBankingError => e
        redirect_to bank_connections_path, alert: "Connection failed: #{e.message}"
        end
    end

    def sync
        @bank_connection.sync_data!
        redirect_back(fallback_location: @bank_connection, notice: 'Sync initiated. Data will be updated shortly.')
    end

    def destroy
        @bank_connection.update!(status: 'disconnected')
        redirect_to bank_connections_path, notice: 'Bank connection removed successfully.'
    end

    private

    def set_bank_connection
        @bank_connection = current_user.bank_connections.find(params[:id])
    end

    def bank_connection_params
        params.require(:bank_connection).permit(:bank_code, :bank_name, :account_number)
    end
end