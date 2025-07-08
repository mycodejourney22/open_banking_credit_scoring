# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!
  
  # def index
  #   @bank_connections = current_user.bank_connections.includes(:account_balances, :transactions)
  #   @latest_credit_score = current_user.credit_scores&.order(created_at: :desc)&.first
    
  #   # Calculate total balance from latest account balances
  #   @total_balance = calculate_total_balance
    
  #   # Get recent transactions from all connected accounts
  #   @recent_transactions = get_recent_transactions
    
  #   # Calculate spending data for charts
  #   @monthly_spending = calculate_monthly_spending
  #   @spending_by_category = calculate_spending_by_category
  # end

  def index
    @bank_connections = current_user.bank_connections.includes(:account_balances, :transactions)
    @latest_credit_score = current_user.credit_scores&.order(created_at: :desc)&.first
    
    # Calculate total balance from latest account balances
    @total_balance = calculate_total_balance
    
    # Get recent transactions from all connected accounts
    @recent_transactions = get_recent_transactions
    
    # Calculate spending data for charts
    @monthly_spending = calculate_monthly_spending
    @spending_by_category = calculate_spending_by_category
    
    # Loan application data
    @active_loan_applications = current_user.loan_applications.active.count
    @total_loans_disbursed = current_user.loan_applications.where(status: 'disbursed').sum(:amount_approved)
  end
  
  private
  
  def calculate_total_balance
    total = 0
    
    @bank_connections.each do |connection|
      latest_balance = connection.account_balances.order(:created_at).last
      total += latest_balance&.current_balance&.to_f || 0
    end
    
    total
  end
  
  def get_recent_transactions
    # Get last 10 transactions across all connections
    if @bank_connections.any?
      Transaction.joins(:bank_connection)
                 .where(bank_connection: { user: current_user })
                 .order(transaction_date: :desc, created_at: :desc)
                 .limit(10)
                 .includes(:bank_connection)
    else
      Transaction.none
    end
  end
  
  def calculate_monthly_spending
    # Calculate spending for last 12 months
    spending_data = {}
    
    (0..11).each do |i|
      date = i.months.ago.beginning_of_month
      month_spending = Transaction.joins(:bank_connection)
                                 .where(bank_connection: { user: current_user })
                                 .where(transaction_date: date.beginning_of_month..date.end_of_month)
                                 .where('amount < 0') # Only outgoing transactions
                                 .sum('ABS(amount)') || 0
      
      spending_data[date.strftime("%b %Y")] = month_spending
    end
    
    spending_data
  end
  
  def calculate_spending_by_category
    # Group spending by transaction type for last 3 months
    return {} unless @bank_connections.any?
    
    categories = Transaction.joins(:bank_connection)
                           .where(bank_connection: { user: current_user })
                           .where(transaction_date: 3.months.ago..)
                           .where('amount < 0') # Only outgoing transactions
                           .group(:transaction_type)
                           .sum('ABS(amount)')
    
    # Convert to more readable category names
    categories.transform_keys do |key|
      case key&.downcase
      when 'debit', 'pos', 'web'
        'Shopping & Purchases'
      when 'transfer', 'nip'
        'Transfers'
      when 'atm'
        'ATM Withdrawals'
      when 'fee', 'charge'
        'Bank Fees'
      when 'bill_payment'
        'Bill Payments'
      else
        key&.humanize || 'Other'
      end
    end
  end
end