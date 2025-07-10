class LoanProductsController < ApplicationController
    before_action :authenticate_user!
    
    def index
      @loan_products = LoanProduct.active
      @user_credit_score = current_user.credit_scores.recent.first&.score
      @eligible_products = @loan_products.select { |product| product.eligible_for_user?(current_user) }
    end
    
    def show
      @loan_product = LoanProduct.find(params[:id])
      @user_credit_score = current_user.credit_scores.recent.first&.score
      @eligible = @loan_product.eligible_for_user?(current_user)
      
      if @user_credit_score
        @estimated_rate = @loan_product.interest_rate_for_score(@user_credit_score)
        @monthly_income = estimate_monthly_income
        @max_amount = @loan_product.max_amount_for_income(@monthly_income)
      end
    end
    
    private
    
    def estimate_monthly_income
      # Get average monthly income from latest credit score analysis
      latest_score = current_user.credit_scores.recent.first
      return 0 unless latest_score&.analysis_data
      
      latest_score.analysis_data.dig('income_analysis', 'average_monthly_income') || 0
    end

end