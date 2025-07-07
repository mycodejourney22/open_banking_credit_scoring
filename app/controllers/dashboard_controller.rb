 # app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    @user = current_user
    @bank_connections = current_user.bank_connections.active.includes(:account_balances)
    @latest_credit_score = current_user.latest_credit_score
    @financial_profile = current_user.financial_profile
    @recent_transactions = current_user.transactions.recent.limit(10)
    @total_balance = current_user.total_balance
    
    # Chart data
    @monthly_spending = current_user.transactions.debits
                                   .group_by_month(:transaction_date, last: 6)
                                   .sum(:amount)
    
    @spending_by_category = current_user.transactions.debits
                                       .where(transaction_date: 30.days.ago..Time.current)
                                       .group(:category)
                                       .sum(:amount)
  end
end