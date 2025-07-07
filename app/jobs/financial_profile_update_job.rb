# app/jobs/financial_profile_update_job.rb
class FinancialProfileUpdateJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    return unless user.has_active_bank_connections?

    # Calculate financial metrics from last 12 months of data
    transactions = user.transactions.where(transaction_date: 12.months.ago..Time.current)
    
    return if transactions.empty?

    profile_data = {
      average_monthly_income: calculate_average_monthly_income(transactions),
      average_monthly_expenses: calculate_average_monthly_expenses(transactions),
      savings_rate: 0, # Will be calculated after income and expenses
      debt_to_income_ratio: calculate_debt_to_income_ratio(transactions),
      expense_volatility: calculate_expense_volatility(transactions),
      transaction_frequency: calculate_transaction_frequency(transactions),
      spending_categories: calculate_spending_categories(transactions),
      income_sources: calculate_income_sources(transactions),
      profile_updated_at: Time.current
    }

    # Calculate savings rate
    if profile_data[:average_monthly_income] > 0
      profile_data[:savings_rate] = [
        (profile_data[:average_monthly_income] - profile_data[:average_monthly_expenses]) / profile_data[:average_monthly_income],
        0
      ].max
    end

    # Update or create financial profile
    if user.financial_profile
      user.financial_profile.update!(profile_data)
    else
      user.create_financial_profile!(profile_data)
    end

    # Recalculate credit score
    CreditScoreCalculationJob.perform_async(user.id)
  end

  private

  def calculate_average_monthly_income(transactions)
    monthly_incomes = transactions.credits
                                .group_by_month(:transaction_date, last: 12)
                                .sum(:amount)
    
    return 0 if monthly_incomes.empty?
    
    monthly_incomes.values.sum / monthly_incomes.keys.count.to_f
  end

  def calculate_average_monthly_expenses(transactions)
    monthly_expenses = transactions.debits
                                 .group_by_month(:transaction_date, last: 12)
                                 .sum(:amount)
    
    return 0 if monthly_expenses.empty?
    
    monthly_expenses.values.sum / monthly_expenses.keys.count.to_f
  end

  def calculate_debt_to_income_ratio(transactions)
    # Identify debt payments (loans, credit cards, etc.)
    debt_keywords = ['loan', 'credit', 'mortgage', 'debt', 'installment']
    debt_transactions = transactions.debits.where(
      debt_keywords.map { |keyword| "description ILIKE ?" }.join(' OR '),
      *debt_keywords.map { |keyword| "%#{keyword}%" }
    )
    
    monthly_debt_payments = debt_transactions.group_by_month(:transaction_date, last: 12)
                                           .sum(:amount)
    
    return 0 if monthly_debt_payments.empty?
    
    avg_monthly_debt = monthly_debt_payments.values.sum / monthly_debt_payments.keys.count.to_f
    avg_monthly_income = calculate_average_monthly_income(transactions)
    
    avg_monthly_income > 0 ? avg_monthly_debt / avg_monthly_income : 0
  end

  def calculate_expense_volatility(transactions)
    monthly_expenses = transactions.debits
                                 .group_by_month(:transaction_date, last: 12)
                                 .sum(:amount)
                                 .values
    
    return 0 if monthly_expenses.length < 3
    
    mean = monthly_expenses.sum / monthly_expenses.length.to_f
    variance = monthly_expenses.sum { |expense| (expense - mean) ** 2 } / monthly_expenses.length.to_f
    standard_deviation = Math.sqrt(variance)
    
    mean > 0 ? standard_deviation / mean : 0
  end

  def calculate_transaction_frequency(transactions)
    transactions.count / 12.0
  end

  def calculate_spending_categories(transactions)
    transactions.debits
               .group(:category)
               .sum(:amount)
               .transform_keys(&:to_s)
  end

  def calculate_income_sources(transactions)
    transactions.credits
               .group(:category)
               .sum(:amount)
               .transform_keys(&:to_s)
  end
end