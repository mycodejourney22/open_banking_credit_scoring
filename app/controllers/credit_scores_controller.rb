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
      
      # Check if we have enough transaction data
      transaction_count = current_user.bank_connections.joins(:transactions).count
      if transaction_count < 10
        redirect_to dashboard_path, alert: 'Insufficient transaction data. Please wait for more data to sync or connect additional accounts.'
        return
      end
      
      begin
        @credit_score = CreditScore.calculate_for_user(current_user)
        redirect_to @credit_score, notice: 'Credit score calculated successfully!'
      rescue => e
        Rails.logger.error "Credit score calculation failed: #{e.message}"
        redirect_to dashboard_path, alert: 'Unable to calculate credit score at this time. Please try again later.'
      end
    end
    
    def refresh
      calculate
    end
end
  