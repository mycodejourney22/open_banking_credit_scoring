class FinancialProfile < ApplicationRecord
  belongs_to :user

  def update_profile!
    FinancialProfileUpdateJob.perform_async(user_id)
  end

  def financial_health_score
    return 0 if average_monthly_income.zero?

    health_factors = []
    
    # Savings rate (0-30 points)
    health_factors << [savings_rate * 100, 30].min
    
    # Debt to income ratio (0-25 points) - lower is better
    debt_score = debt_to_income_ratio > 0.4 ? 0 : (1 - debt_to_income_ratio) * 25
    health_factors << debt_score
    
    # Expense volatility (0-20 points) - lower is better
    volatility_score = expense_volatility > 0.3 ? 0 : (1 - expense_volatility) * 20
    health_factors << volatility_score
    
    # Transaction frequency (0-25 points)
    frequency_score = [transaction_frequency / 50.0 * 25, 25].min
    health_factors << frequency_score

    health_factors.sum.round(2)
  end
end