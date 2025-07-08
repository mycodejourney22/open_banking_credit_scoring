# app/models/loan_product.rb
class LoanProduct < ApplicationRecord
    validates :name, presence: true
    validates :min_amount, :max_amount, presence: true, numericality: { greater_than: 0 }
    validates :min_term_months, :max_term_months, presence: true, numericality: { greater_than: 0 }
    validates :interest_rate_min, :interest_rate_max, presence: true, numericality: { greater_than: 0 }
    validates :min_credit_score, presence: true, numericality: { in: 300..850 }
    
    scope :active, -> { where(active: true) }
    scope :for_credit_score, ->(score) { where('min_credit_score <= ?', score) }
    
    def interest_rate_for_score(credit_score)
      # Linear interpolation based on credit score
      score_range = 850 - min_credit_score
      rate_range = interest_rate_max - interest_rate_min
      
      if credit_score >= 750
        interest_rate_min
      elsif credit_score <= min_credit_score
        interest_rate_max
      else
        score_factor = (credit_score - min_credit_score).to_f / score_range
        interest_rate_max - (rate_range * score_factor)
      end.round(2)
    end
    
    def max_amount_for_income(monthly_income)
      # Conservative approach: 5x monthly income or product max, whichever is lower
      income_based_max = monthly_income * 5
      [income_based_max, max_amount].min
    end
    
    def eligible_for_user?(user)
      return false unless active?
      
      latest_score = user.credit_scores.order(:created_at).last
      return false unless latest_score
      
      latest_score.score >= min_credit_score
    end
end