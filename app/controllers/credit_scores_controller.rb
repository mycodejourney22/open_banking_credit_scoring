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
        # Check if user has connected bank accounts
        unless current_user.bank_connections.active.any?
          redirect_to bank_connections_path, alert: 'Please connect at least one bank account to calculate your credit score.'
          return
        end
        
        begin
          # First, try to get transactions from database
          transaction_count = current_user.bank_connections.joins(:transactions).count
          
          if transaction_count < 10
            # Not enough synced data, fetch directly from API
            Rails.logger.info "Insufficient synced transaction data (#{transaction_count}), fetching from API..."
            
            fresh_data = fetch_fresh_transaction_data
            
            if fresh_data[:total_transactions] < 10
              redirect_to dashboard_path, 
                         alert: "Insufficient transaction data (#{fresh_data[:total_transactions]} found). Please ensure your connected accounts have recent transaction history."
              return
            end
            
            # Calculate credit score using fresh API data
            @credit_score = calculate_credit_score_with_api_data(fresh_data)
          else
            # Use synced data
            @credit_score = CreditScore.calculate_for_user(current_user)
          end
          
          redirect_to @credit_score, notice: 'Credit score calculated successfully!'
          
        rescue OpenBankingApiService::OpenBankingError => e
          Rails.logger.error "Open Banking API error during credit score calculation: #{e.message}"
          redirect_to dashboard_path, 
                     alert: 'Unable to fetch transaction data from your bank. Please try again later or contact support.'
        rescue => e
          Rails.logger.error "Credit score calculation failed: #{e.message}"
          redirect_to dashboard_path, 
                     alert: 'Unable to calculate credit score at this time. Please try again later.'
        end
    end
      
    
    def refresh
      calculate
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
end
  