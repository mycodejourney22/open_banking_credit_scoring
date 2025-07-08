# app/services/credit_analysis_service.rb
class CreditAnalysisService
    def initialize(user)
      @user = user
      @bank_connections = user.bank_connections.active.includes(:transactions, :account_balances)
      @transactions = Transaction.joins(:bank_connection)
                                .where(bank_connection: { user: user })
                                .order(:transaction_date)
    end
  
    def calculate_credit_score
      return 0 if @transactions.empty?
  
      # Credit score components (weighted)
      income_stability = calculate_income_stability * 0.25      # 25%
      cash_flow_pattern = calculate_cash_flow_pattern * 0.20    # 20%
      spending_behavior = calculate_spending_behavior * 0.15    # 15%
      account_management = calculate_account_management * 0.15  # 15%
      financial_commitments = calculate_financial_commitments * 0.10 # 10%
      transaction_diversity = calculate_transaction_diversity * 0.10 # 10%
      account_longevity = calculate_account_longevity * 0.05    # 5%
  
      total_score = [
        income_stability,
        cash_flow_pattern,
        spending_behavior,
        account_management,
        financial_commitments,
        transaction_diversity,
        account_longevity
      ].sum
  
      # Scale to 300-850 (standard credit score range)
      scaled_score = 300 + (total_score * 5.5)
      scaled_score.round.clamp(300, 850)
    end
  
    def generate_credit_report
      {
        overall_score: calculate_credit_score,
        risk_level: determine_risk_level,
        analysis: {
          income_analysis: analyze_income,
          cash_flow_analysis: analyze_cash_flow,
          spending_analysis: analyze_spending,
          account_health: analyze_account_health,
          payment_behavior: analyze_payment_behavior,
          financial_stability: analyze_financial_stability
        },
        recommendations: generate_recommendations,
        loan_eligibility: assess_loan_eligibility,
        generated_at: Time.current
      }
    end
  
    private
  
    # INCOME ANALYSIS (25% weight)
    def calculate_income_stability
      recent_months = 6
      monthly_incomes = calculate_monthly_incomes(recent_months)
      
      return 0 if monthly_incomes.empty?
  
      # Factors: consistency, growth, amount
      consistency_score = calculate_income_consistency(monthly_incomes)
      growth_score = calculate_income_growth(monthly_incomes)
      amount_score = calculate_income_amount(monthly_incomes)
  
      (consistency_score + growth_score + amount_score) / 3
    end
  
    def calculate_monthly_incomes(months)
      end_date = Date.current
      start_date = months.months.ago.beginning_of_month
  
      monthly_data = {}
      
      (0...months).each do |i|
        month_start = i.months.ago.beginning_of_month
        month_end = i.months.ago.end_of_month
        
        # Identify income transactions (credits from external sources)
        income = @transactions.where(transaction_date: month_start..month_end)
                             .where('amount > 0')
                             .where(transaction_type: ['SALARY', 'CREDIT', 'TRANSFER', 'DEPOSIT'])
                             .sum(:amount)
        
        monthly_data[month_start.strftime('%Y-%m')] = income
      end
  
      monthly_data
    end
  
    def calculate_income_consistency(monthly_incomes)
      incomes = monthly_incomes.values.reject(&:zero?)
      return 0 if incomes.length < 3
  
      mean = incomes.sum / incomes.length
      variance = incomes.map { |income| (income - mean) ** 2 }.sum / incomes.length
      coefficient_of_variation = Math.sqrt(variance) / mean
  
      # Lower CV = higher consistency = better score
      [100 - (coefficient_of_variation * 100), 0].max.clamp(0, 100)
    end
  
    def calculate_income_growth(monthly_incomes)
      incomes = monthly_incomes.values.reject(&:zero?)
      return 50 if incomes.length < 2
  
      recent_avg = incomes.last(3).sum / [incomes.last(3).length, 1].max
      older_avg = incomes.first(3).sum / [incomes.first(3).length, 1].max
  
      return 50 if older_avg.zero?
  
      growth_rate = ((recent_avg - older_avg) / older_avg) * 100
      
      # Positive growth gets higher score
      case growth_rate
      when 10..Float::INFINITY then 100
      when 5..10 then 80
      when 0..5 then 60
      when -5..0 then 40
      when -10..-5 then 20
      else 0
      end
    end
  
    def calculate_income_amount(monthly_incomes)
      avg_income = monthly_incomes.values.sum / [monthly_incomes.values.length, 1].max
      
      # Score based on income levels (Nigerian context)
      case avg_income
      when 500_000..Float::INFINITY then 100  # ₦500k+ per month
      when 300_000..500_000 then 90           # ₦300-500k
      when 200_000..300_000 then 80           # ₦200-300k
      when 150_000..200_000 then 70           # ₦150-200k
      when 100_000..150_000 then 60           # ₦100-150k
      when 50_000..100_000 then 50            # ₦50-100k
      when 30_000..50_000 then 40             # ₦30-50k
      else 20                                 # Below ₦30k
      end
    end
  
    # CASH FLOW ANALYSIS (20% weight)
    def calculate_cash_flow_pattern
      monthly_flows = calculate_monthly_cash_flows
      return 0 if monthly_flows.empty?
  
      positive_months = monthly_flows.count { |flow| flow > 0 }
      total_months = monthly_flows.length
  
      # Percentage of months with positive cash flow
      positive_ratio = positive_months.to_f / total_months
      
      # Adjust for consistency
      flows_std_dev = calculate_standard_deviation(monthly_flows)
      avg_flow = monthly_flows.sum / monthly_flows.length
      
      consistency_factor = avg_flow.zero? ? 0 : (1 - (flows_std_dev / avg_flow.abs)).clamp(0, 1)
      
      (positive_ratio * 70 + consistency_factor * 30).clamp(0, 100)
    end
  
    def calculate_monthly_cash_flows
      6.times.map do |i|
        month_start = i.months.ago.beginning_of_month
        month_end = i.months.ago.end_of_month
        
        credits = @transactions.where(transaction_date: month_start..month_end)
                              .where('amount > 0').sum(:amount)
        debits = @transactions.where(transaction_date: month_start..month_end)
                             .where('amount < 0').sum('ABS(amount)')
        
        credits - debits
      end
    end
  
    # SPENDING BEHAVIOR (15% weight)
    def calculate_spending_behavior
      spending_categories = categorize_spending
      return 0 if spending_categories.empty?
  
      # Analyze spending patterns
      essential_ratio = calculate_essential_spending_ratio(spending_categories)
      discretionary_control = calculate_discretionary_control(spending_categories)
      large_purchase_frequency = calculate_large_purchase_pattern
  
      (essential_ratio * 0.4 + discretionary_control * 0.4 + large_purchase_frequency * 0.2).clamp(0, 100)
    end
  
    def categorize_spending
      categories = {
        essential: 0,      # Bills, groceries, utilities
        discretionary: 0,  # Entertainment, dining, shopping
        financial: 0,      # Investments, savings transfers
        large_purchases: 0 # Purchases > 50k
      }
  
      @transactions.where('amount < 0').find_each do |txn|
        amount = txn.amount.abs
        
        case txn.transaction_type&.downcase
        when 'bill_payment', 'utility'
          categories[:essential] += amount
        when 'atm', 'pos', 'web'
          if amount > 50_000
            categories[:large_purchases] += amount
          else
            categories[:discretionary] += amount
          end
        when 'transfer'
          # Analyze narration to determine if savings/investment
          if txn.description&.match?(/save|invest|fixed/i)
            categories[:financial] += amount
          else
            categories[:discretionary] += amount
          end
        else
          categories[:discretionary] += amount
        end
      end
  
      categories
    end
  
    def calculate_essential_spending_ratio(categories)
      total_spending = categories.values.sum
      return 100 if total_spending.zero?
  
      essential_ratio = categories[:essential] / total_spending
      
      # Optimal essential spending: 40-60%
      case essential_ratio
      when 0.4..0.6 then 100
      when 0.3..0.4, 0.6..0.7 then 80
      when 0.2..0.3, 0.7..0.8 then 60
      else 40
      end
    end
  
    # ACCOUNT MANAGEMENT (15% weight)
    def calculate_account_management
      balance_scores = calculate_balance_management
      overdraft_score = calculate_overdraft_behavior
      transaction_frequency = calculate_transaction_frequency
  
      (balance_scores * 0.5 + overdraft_score * 0.3 + transaction_frequency * 0.2).clamp(0, 100)
    end
  
    def calculate_balance_management
      recent_balances = @bank_connections.joins(:account_balances)
                                       .where(account_balances: { created_at: 3.months.ago.. })
                                       .pluck(:current_balance)
      
      return 50 if recent_balances.empty?
  
      avg_balance = recent_balances.sum / recent_balances.length
      min_balance = recent_balances.min
      
      # Score based on average balance and minimum balance maintenance
      avg_score = case avg_balance
                  when 100_000..Float::INFINITY then 100
                  when 50_000..100_000 then 80
                  when 20_000..50_000 then 60
                  when 10_000..20_000 then 40
                  else 20
                  end
  
      min_score = min_balance >= 0 ? 100 : 0  # No overdrafts = good
      
      (avg_score + min_score) / 2
    end
  
    def calculate_overdraft_behavior
      overdraft_count = @transactions.where('amount < 0')
                                    .where('balance_after < 0')
                                    .count
  
      total_transactions = @transactions.count
      return 100 if total_transactions.zero?
  
      overdraft_ratio = overdraft_count.to_f / total_transactions
      
      case overdraft_ratio
      when 0 then 100
      when 0..0.05 then 80
      when 0.05..0.1 then 60
      when 0.1..0.2 then 40
      else 20
      end
    end
  
    # FINANCIAL COMMITMENTS (10% weight)
    def calculate_financial_commitments
      recurring_payments = identify_recurring_payments
      debt_service_ratio = calculate_debt_service_ratio
      
      (recurring_payments * 0.6 + debt_service_ratio * 0.4).clamp(0, 100)
    end
  
    def identify_recurring_payments
      # Look for regular bill payments, loan payments
      recurring_patterns = @transactions.where('amount < 0')
                                       .group(:description)
                                       .having('COUNT(*) >= 3')
                                       .count
  
      # Score based on number of regular commitments
      case recurring_patterns.count
      when 0..2 then 100      # Few commitments = good
      when 3..5 then 80       # Moderate commitments
      when 6..8 then 60       # Many commitments
      else 40                 # Too many commitments
      end
    end
  
    # ANALYSIS METHODS
    def analyze_income
      monthly_incomes = calculate_monthly_incomes(6)
      avg_income = monthly_incomes.values.sum / [monthly_incomes.values.length, 1].max
      
      {
        average_monthly_income: avg_income,
        income_trend: calculate_income_trend(monthly_incomes),
        income_sources: identify_income_sources,
        stability_rating: calculate_income_consistency(monthly_incomes)
      }
    end
  
    def analyze_cash_flow
      flows = calculate_monthly_cash_flows
      {
        monthly_cash_flows: flows,
        average_monthly_flow: flows.sum / [flows.length, 1].max,
        positive_months: flows.count { |f| f > 0 },
        cash_flow_trend: flows.last(3).sum > flows.first(3).sum ? 'improving' : 'declining'
      }
    end
  
    def analyze_spending
      categories = categorize_spending
      total = categories.values.sum
      
      {
        total_monthly_spending: total / 6,
        spending_breakdown: categories.transform_values { |v| total.zero? ? 0 : (v / total * 100).round(2) },
        spending_trend: 'stable', # Could be enhanced
        largest_expense_category: categories.max_by { |k, v| v }&.first
      }
    end
  
    def analyze_account_health
      latest_balances = @bank_connections.joins(:account_balances)
                                        .order('account_balances.created_at DESC')
                                        .limit(1)
                                        .pluck(:current_balance)
      
      {
        current_total_balance: latest_balances.sum,
        account_count: @bank_connections.count,
        overdraft_frequency: calculate_overdraft_frequency,
        average_daily_balance: calculate_average_daily_balance
      }
    end
  
    def assess_loan_eligibility
      score = calculate_credit_score
      monthly_income = calculate_monthly_incomes(3).values.sum / 3
      debt_to_income = calculate_debt_to_income_ratio
      
      max_loan_amount = calculate_max_loan_amount(monthly_income, debt_to_income)
      
      {
        eligible: score >= 400 && monthly_income >= 50_000,
        max_loan_amount: max_loan_amount,
        recommended_loan_amount: max_loan_amount * 0.8,
        interest_rate_range: determine_interest_rate_range(score),
        loan_term_options: determine_loan_terms(score),
        conditions: generate_loan_conditions(score, monthly_income)
      }
    end
  
    def calculate_max_loan_amount(monthly_income, debt_to_income)
      # Conservative approach: 30% of income for loan payments
      available_income = monthly_income * 0.3
      available_income -= (monthly_income * debt_to_income)
      
      # Assume 24-month term, 15% annual interest
      monthly_rate = 0.15 / 12
      term_months = 24
      
      # Calculate loan amount using PMT formula
      if monthly_rate > 0
        loan_amount = available_income * ((1 - (1 + monthly_rate) ** -term_months) / monthly_rate)
      else
        loan_amount = available_income * term_months
      end
      
      [loan_amount, 0].max.round(-3) # Round to nearest thousand
    end
  
    def determine_risk_level
      score = calculate_credit_score
      
      case score
      when 750..850 then 'Excellent'
      when 700..749 then 'Good'
      when 650..699 then 'Fair'
      when 600..649 then 'Poor'
      else 'Very Poor'
      end
    end
  
    def determine_interest_rate_range(score)
      case score
      when 750..850 then '8-12%'
      when 700..749 then '12-16%'
      when 650..699 then '16-20%'
      when 600..649 then '20-25%'
      else '25-30%'
      end
    end
  
    def generate_recommendations
      recommendations = []
      score = calculate_credit_score
      
      if score < 600
        recommendations << "Maintain positive account balances to avoid overdraft fees"
        recommendations << "Establish consistent income deposits"
      end
      
      if calculate_income_consistency(calculate_monthly_incomes(6)) < 60
        recommendations << "Work on stabilizing your income sources"
      end
      
      if calculate_cash_flow_pattern < 50
        recommendations << "Focus on improving monthly cash flow management"
      end
      
      recommendations << "Continue building your financial history through regular transactions"
      
      recommendations
    end
  
    # Helper methods
    def calculate_standard_deviation(values)
      return 0 if values.empty?
      
      mean = values.sum.to_f / values.length
      variance = values.map { |v| (v - mean) ** 2 }.sum / values.length
      Math.sqrt(variance)
    end
  
    def calculate_transaction_frequency
      days_with_transactions = @transactions.group(:transaction_date).count.keys.length
      total_days = (@transactions.maximum(:transaction_date) - @transactions.minimum(:transaction_date)).to_i + 1
      
      return 50 if total_days.zero?
      
      frequency_ratio = days_with_transactions.to_f / total_days
      (frequency_ratio * 100).clamp(0, 100)
    end
  
    def calculate_debt_to_income_ratio
      # Simplified - look for loan payments in transaction descriptions
      monthly_debt_payments = @transactions.where('amount < 0')
                                          .where('description ILIKE ? OR description ILIKE ?', '%loan%', '%credit%')
                                          .where(transaction_date: 3.months.ago..)
                                          .sum('ABS(amount)') / 3
  
      monthly_income = calculate_monthly_incomes(3).values.sum / 3
      
      return 0 if monthly_income.zero?
      
      monthly_debt_payments / monthly_income
    end
  
    def calculate_overdraft_frequency
      overdraft_transactions = @transactions.where('balance_after < 0').count
      total_transactions = @transactions.count
      
      return 0 if total_transactions.zero?
      
      (overdraft_transactions.to_f / total_transactions * 100).round(2)
    end
  
    def calculate_average_daily_balance
      # Simplified calculation using available balance data
      balances = @bank_connections.joins(:account_balances)
                                 .pluck(:current_balance)
      
      return 0 if balances.empty?
      
      balances.sum / balances.length
    end
  
    def identify_income_sources
      income_transactions = @transactions.where('amount > 0')
                                        .group(:transaction_type)
                                        .sum(:amount)
      
      income_transactions.transform_keys { |key| key&.humanize || 'Unknown' }
    end
  
    def calculate_income_trend(monthly_incomes)
      values = monthly_incomes.values
      return 'stable' if values.length < 2
      
      recent_avg = values.last(3).sum / 3.0
      older_avg = values.first(3).sum / 3.0
      
      if recent_avg > older_avg * 1.1
        'increasing'
      elsif recent_avg < older_avg * 0.9
        'decreasing'
      else
        'stable'
      end
    end
  
    def calculate_discretionary_control(categories)
      # Score based on ratio of discretionary to essential spending
      total_spending = categories[:essential] + categories[:discretionary]
      return 100 if total_spending.zero?
      
      discretionary_ratio = categories[:discretionary] / total_spending
      
      case discretionary_ratio
      when 0..0.3 then 100    # Very controlled
      when 0.3..0.5 then 80   # Well controlled
      when 0.5..0.7 then 60   # Moderate control
      else 40                 # Poor control
      end
    end
  
    def calculate_large_purchase_pattern
      large_purchases = @transactions.where('amount < -50000').count
      total_months = 6
      
      purchases_per_month = large_purchases.to_f / total_months
      
      case purchases_per_month
      when 0..0.5 then 100      # Rare large purchases = good control
      when 0.5..1 then 80       # Occasional large purchases
      when 1..2 then 60         # Regular large purchases
      else 40                   # Frequent large purchases
      end
    end
  
    def calculate_transaction_diversity
      # Score based on variety of transaction types and channels
      transaction_types = @transactions.distinct.count(:transaction_type)
      channels = @transactions.where.not(metadata: nil)
                             .distinct
                             .count("metadata->>'channel'")
      
      diversity_score = [transaction_types * 10, 100].min + [channels * 10, 100].min
      (diversity_score / 2).clamp(0, 100)
    end
  
    def calculate_account_longevity
      # Score based on account age and transaction history length
      oldest_transaction = @transactions.minimum(:transaction_date)
      return 0 unless oldest_transaction
      
      days_active = (Date.current - oldest_transaction).to_i
      months_active = days_active / 30.0
      
      case months_active
      when 0..3 then 20
      when 3..6 then 40
      when 6..12 then 60
      when 12..24 then 80
      else 100
      end
    end
  
    def determine_loan_terms(score)
      case score
      when 750..850 then ['12 months', '24 months', '36 months']
      when 700..749 then ['12 months', '24 months']
      when 650..699 then ['12 months', '18 months']
      else ['6 months', '12 months']
      end
    end
  
    def generate_loan_conditions(score, monthly_income)
      conditions = []
      
      if score < 650
        conditions << "Require collateral or guarantor"
      end
      
      if monthly_income < 100_000
        conditions << "Maximum loan amount: ₦500,000"
      end
      
      if calculate_overdraft_frequency > 5
        conditions << "Maintain positive account balance for 3 months"
      end
      
      conditions << "Regular income deposits required"
      conditions << "Loan insurance required"
      
      conditions
    end
end