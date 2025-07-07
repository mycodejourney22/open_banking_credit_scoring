 # app/controllers/credit_scores_controller.rb
 class CreditScoresController < ApplicationController
    def index
      @credit_scores = current_user.credit_scores.recent.limit(10)
      @latest_score = @credit_scores.first
      @score_history = current_user.credit_scores
                                  .select(:score, :calculated_at)
                                  .order(:calculated_at)
                                  .last(12)
    end
  
    def show
      @credit_score = current_user.credit_scores.find(params[:id])
    end
  
    def calculate
      if current_user.financial_profile.present?
        CreditScoreCalculationJob.perform_async(current_user.id)
        redirect_to credit_scores_path, notice: 'Credit score calculation initiated. Please refresh in a few moments.'
      else
        redirect_to bank_connections_path, alert: 'Please connect a bank account first to calculate your credit score.'
      end
    end
  end