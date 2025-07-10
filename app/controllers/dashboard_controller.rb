# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @latest_credit_score = current_user.credit_scores.recent.first
    @bank_connections = current_user.bank_connections.includes(:account_balances, :transactions)
    @total_balance = calculate_total_balance
    
    # Calculate financial metrics
    @monthly_income = calculate_current_month_income
    @monthly_spending_current = calculate_current_month_spending
    @avg_monthly_income = calculate_average_monthly_income
    @avg_monthly_spending = calculate_average_monthly_spending
    
    # Get transaction history
    @recent_transactions = get_recent_transactions
    
    # Calculate trends for charts
    @monthly_spending_trend = calculate_monthly_spending_trend
    @monthly_income_trend = calculate_monthly_income_trend
    @spending_by_category = calculate_spending_by_category
  end
  
  private
  
  def calculate_total_balance
    return 0 unless @bank_connections.any?
    
    @bank_connections.sum do |connection|
      latest_balance = connection.account_balances.order(:created_at).last
      latest_balance&.current_balance || 0
    end
  end
  
  def calculate_current_month_income
    return 0 unless @bank_connections.any?
    
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month
    
    Transaction.joins(:bank_connection)
               .where(bank_connection: { user: current_user })
               .where(transaction_date: current_month_start..current_month_end)
               .where('amount > 0') # Credits only
               .sum(:amount)
  end
  
  def calculate_current_month_spending
    return 0 unless @bank_connections.any?
    
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month
    
    Transaction.joins(:bank_connection)
               .where(bank_connection: { user: current_user })
               .where(transaction_date: current_month_start..current_month_end)
               .where('amount < 0') # Debits only
               .sum('ABS(amount)')
  end
  
  def calculate_average_monthly_income
    return 0 unless @bank_connections.any?
    
    # Calculate for last 6 months
    months_data = {}
    6.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      
      income = Transaction.joins(:bank_connection)
                         .where(bank_connection: { user: current_user })
                         .where(transaction_date: month_start..month_end)
                         .where('amount > 0')
                         .sum(:amount)
      
      months_data[month_start.strftime('%Y-%m')] = income
    end
    
    return 0 if months_data.empty?
    months_data.values.sum / months_data.length
  end
  
  def calculate_average_monthly_spending
    return 0 unless @bank_connections.any?
    
    # Calculate for last 6 months
    months_data = {}
    6.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      
      spending = Transaction.joins(:bank_connection)
                           .where(bank_connection: { user: current_user })
                           .where(transaction_date: month_start..month_end)
                           .where('amount < 0')
                           .sum('ABS(amount)')
      
      months_data[month_start.strftime('%Y-%m')] = spending
    end
    
    return 0 if months_data.empty?
    months_data.values.sum / months_data.length
  end
  
  def get_recent_transactions
    return Transaction.none unless @bank_connections.any?
    
    Transaction.joins(:bank_connection)
               .where(bank_connection: { user: current_user })
               .order(transaction_date: :desc, created_at: :desc)
               .limit(20)
               .includes(:bank_connection)
  end
  
  def calculate_monthly_spending_trend
    return {} unless @bank_connections.any?
    
    trend_data = {}
    6.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_label = month_start.strftime('%b %Y')
      
      spending = Transaction.joins(:bank_connection)
                           .where(bank_connection: { user: current_user })
                           .where(transaction_date: month_start..month_end)
                           .where('amount < 0')
                           .sum('ABS(amount)')
      
      trend_data[month_label] = spending
    end
    
    # Return in chronological order
    trend_data.sort.reverse.to_h
  end
  
  def calculate_monthly_income_trend
    return {} unless @bank_connections.any?
    
    trend_data = {}
    6.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_label = month_start.strftime('%b %Y')
      
      income = Transaction.joins(:bank_connection)
                         .where(bank_connection: { user: current_user })
                         .where(transaction_date: month_start..month_end)
                         .where('amount > 0')
                         .sum(:amount)
      
      trend_data[month_label] = income
    end
    
    # Return in chronological order
    trend_data.sort.reverse.to_h
  end
  
  def calculate_spending_by_category
    return {} unless @bank_connections.any?
    
    # Get last 3 months of spending transactions
    three_months_ago = 3.months.ago.beginning_of_month
    
    transactions = Transaction.joins(:bank_connection)
                             .where(bank_connection: { user: current_user })
                             .where(transaction_date: three_months_ago..)
                             .where('amount < 0')
    
    # Categorize transactions based on description patterns
    categories = {}
    
    transactions.find_each do |transaction|
      category = categorize_transaction(transaction)
      categories[category] ||= 0
      categories[category] += transaction.amount.abs
    end
    
    # Return top 7 categories
    categories.sort_by { |_, amount| -amount }.first(7).to_h
  end
  
  def categorize_transaction(transaction)
    description = (transaction.description || transaction.reference || '').downcase
    
    case description
    when /atm|withdrawal|cash/
      'ATM Withdrawals'
    when /transfer|trf|tfr/
      'Transfers'
    when /pos|purchase|shop|store|market/
      'Shopping & Purchases'
    when /bill|utility|electric|water|internet|phone|cable/
      'Bills & Utilities'
    when /fuel|gas|petrol|station/
      'Fuel & Transportation'
    when /restaurant|food|eat|cafe|kitchen/
      'Food & Dining'
    when /fee|charge|commission|maintenance/
      'Bank Fees'
    when /loan|credit|debt|installment/
      'Loan Payments'
    when /subscription|netflix|spotify|amazon/
      'Subscriptions'
    when /medical|hospital|pharmacy|doctor/
      'Healthcare'
    else
      'Other Expenses'
    end
  end
end