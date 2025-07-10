# # app/services/api_credit_analysis_service.rb
# class ApiCreditAnalysisService
#     def initialize(user, financial_data)
#       @user = user
#       @financial_data = financial_data
#       @transactions = financial_data[:all_transactions]
#       @accounts = financial_data[:accounts]
#       @analysis_date = Time.current
#     end
    
#     def perform_analysis
#       return default_analysis if @transactions.empty?
      
#       analysis_data = {
#         transaction_count: @transactions.length,
#         account_count: @accounts.length,
#         analysis_period: {
#           from: analysis_start_date,
#           to: @analysis_date,
#           months: 6
#         },
#         income_analysis: analyze_income,
#         spending_analysis: analyze_spending,
#         financial_behavior: analyze_financial_behavior,
#         risk_factors: assess_risk_factors,
#         account_stability: analyze_account_stability,
#         calculated_at: @analysis_date
#       }
      
#       score = calculate_composite_score(analysis_data)
#       grade = determine_grade(score)
      
#       {
#         score: score,
#         grade: grade,
#         analysis_data: analysis_data
#       }
#     end
    
#     private
    
#     def default_analysis
#       {
#         score: 300, # Minimum score
#         grade: 'Poor',
#         analysis_data: {
#           transaction_count: 0,
#           account_count: 0,
#           error: 'Insufficient transaction data for analysis'
#         }
#       }
#     end
    
#     def analysis_start_date
#       @analysis_start_date ||= begin
#         earliest_transaction = @transactions.min_by { |t| Date.parse(t['transaction_time'] || t['value_date']) }
#         if earliest_transaction
#           Date.parse(earliest_transaction['transaction_time'] || earliest_transaction['value_date'])
#         else
#           6.months.ago.to_date
#         end
#       end
#     end
    
#     def analyze_income
#       credit_transactions = @transactions.select { |t| t['debit_credit'] == 'CREDIT' }
      
#       monthly_credits = group_transactions_by_month(credit_transactions)
      
#       # Identify salary-like transactions (regular amounts, monthly frequency)
#       potential_salaries = identify_salary_transactions(credit_transactions)
      
#       {
#         total_credits: credit_transactions.sum { |t| t['amount'].to_f },
#         average_monthly_income: monthly_credits.values.sum / [monthly_credits.length, 1].max,
#         salary_transactions: potential_salaries.length,
#         estimated_monthly_salary: potential_salaries.sum { |t| t['amount'].to_f } / [potential_salaries.length, 1].max,
#         income_consistency: calculate_income_consistency(monthly_credits),
#         income_sources: identify_income_sources(credit_transactions)
#       }
#     end
    
#     def analyze_spending
#       debit_transactions = @transactions.select { |t| t['debit_credit'] == 'DEBIT' }
      
#       monthly_debits = group_transactions_by_month(debit_transactions)
      
#       spending_categories = categorize_spending(debit_transactions)
      
#       {
#         total_spending: debit_transactions.sum { |t| t['amount'].to_f },
#         average_monthly_spending: monthly_debits.values.sum / [monthly_debits.length, 1].max,
#         spending_consistency: calculate_spending_consistency(monthly_debits),
#         spending_categories: spending_categories,
#         largest_expense: debit_transactions.max_by { |t| t['amount'].to_f },
#         frequent_merchants: identify_frequent_merchants(debit_transactions)
#       }
#     end
    
#     def analyze_financial_behavior
#       {
#         overdraft_incidents: count_overdraft_incidents,
#         bounce_incidents: count_bounce_incidents,
#         average_balance: calculate_average_balance,
#         balance_volatility: calculate_balance_volatility,
#         transaction_frequency: calculate_transaction_frequency,
#         debt_to_income_ratio: calculate_debt_to_income_ratio,
#         savings_rate: calculate_savings_rate
#       }
#     end
    
#     def assess_risk_factors
#       risk_factors = []
      
#       # High debt-to-income ratio
#       dti = calculate_debt_to_income_ratio
#       risk_factors << "High debt-to-income ratio (#{(dti * 100).round(1)}%)" if dti > 0.6
      
#       # Frequent overdrafts
#       overdrafts = count_overdraft_incidents
#       risk_factors << "Frequent overdrafts (#{overdrafts} incidents)" if overdrafts > 5
      
#       # Low average balance
#       avg_balance = calculate_average_balance
#       risk_factors << "Low average balance (₦#{avg_balance.round(2)})" if avg_balance < 10_000
      
#       # Irregular income
#       income_analysis = analyze_income
#       if income_analysis[:income_consistency] < 0.7
#         risk_factors << "Irregular income pattern"
#       end
      
#       # High spending volatility
#       spending_analysis = analyze_spending
#       if spending_analysis[:spending_consistency] < 0.6
#         risk_factors << "Inconsistent spending patterns"
#       end
      
#       risk_factors
#     end
    
#     def analyze_account_stability
#       {
#         oldest_account_age: calculate_oldest_account_age,
#         account_diversity: @accounts.length,
#         total_relationships: @accounts.map { |a| a['bank_name'] || 'Unknown' }.uniq.length,
#         account_status: @accounts.map { |a| a['status'] || 'ACTIVE' }.uniq
#       }
#     end
    
#     def calculate_composite_score(analysis_data)
#       # Base score
#       score = 300
      
#       # Income factors (up to 200 points)
#       income_score = calculate_income_score(analysis_data[:income_analysis])
#       score += income_score
      
#       # Financial behavior (up to 150 points)
#       behavior_score = calculate_behavior_score(analysis_data[:financial_behavior])
#       score += behavior_score
      
#       # Account stability (up to 100 points)
#       stability_score = calculate_stability_score(analysis_data[:account_stability])
#       score += stability_score
      
#       # Risk factors (deductions)
#       risk_deductions = analysis_data[:risk_factors].length * 25
#       score -= risk_deductions
      
#       # Transaction volume bonus (up to 50 points)
#       transaction_bonus = [analysis_data[:transaction_count] / 10, 50].min
#       score += transaction_bonus
      
#       # Ensure score is within valid range
#       [[score, 300].max, 850].min
#     end
    
#     def calculate_income_score(income_analysis)
#       score = 0
      
#       # Monthly income score (up to 100 points)
#       monthly_income = income_analysis[:average_monthly_income]
#       score += case monthly_income
#                 when 0..50_000 then (monthly_income / 50_000.0 * 40).round
#                 when 50_000..150_000 then 40 + ((monthly_income - 50_000) / 100_000.0 * 40).round
#                 when 150_000..500_000 then 80 + ((monthly_income - 150_000) / 350_000.0 * 20).round
#                 else 100
#                 end
      
#       # Income consistency (up to 100 points)
#       consistency_score = (income_analysis[:income_consistency] * 100).round
#       score += consistency_score
      
#       score
#     end
    
#     def calculate_behavior_score(behavior_analysis)
#       score = 0
      
#       # Overdraft penalty
#       score -= behavior_analysis[:overdraft_incidents] * 10
      
#       # Balance management (up to 60 points)
#       avg_balance = behavior_analysis[:average_balance]
#       balance_score = case avg_balance
#                       when 0..10_000 then (avg_balance / 10_000.0 * 20).round
#                       when 10_000..50_000 then 20 + ((avg_balance - 10_000) / 40_000.0 * 25).round
#                       when 50_000..200_000 then 45 + ((avg_balance - 50_000) / 150_000.0 * 15).round
#                       else 60
#                       end
#       score += balance_score
      
#       # Transaction frequency (up to 40 points)
#       frequency_score = [behavior_analysis[:transaction_frequency] / 10, 40].min
#       score += frequency_score
      
#       # Savings rate bonus (up to 50 points)
#       savings_rate = behavior_analysis[:savings_rate]
#       savings_score = (savings_rate * 100).round if savings_rate > 0
#       score += [savings_score || 0, 50].min
      
#       [score, 150].min
#     end
    
#     def calculate_stability_score(stability_analysis)
#       score = 0
      
#       # Account age (up to 50 points)
#       age_months = stability_analysis[:oldest_account_age]
#       age_score = [age_months * 2, 50].min
#       score += age_score
      
#       # Account diversity (up to 30 points)
#       diversity_score = [stability_analysis[:account_diversity] * 10, 30].min
#       score += diversity_score
      
#       # Bank relationships (up to 20 points)
#       relationship_score = [stability_analysis[:total_relationships] * 10, 20].min
#       score += relationship_score
      
#       score
#     end
    
#     def determine_grade(score)
#       case score
#       when 750..850 then 'Excellent'
#       when 700..749 then 'Very Good'
#       when 650..699 then 'Good'
#       when 600..649 then 'Fair'
#       when 550..599 then 'Poor'
#       else 'Very Poor'
#       end
#     end
    
#     # Helper methods
    
#     def group_transactions_by_month(transactions)
#       transactions.group_by do |transaction|
#         date = Date.parse(transaction['transaction_time'] || transaction['value_date'])
#         date.strftime('%Y-%m')
#       end.transform_values { |txns| txns.sum { |t| t['amount'].to_f } }
#     end
    
#     def identify_salary_transactions(credit_transactions)
#       # Group by amount ranges and frequency
#       amount_groups = credit_transactions.group_by { |t| (t['amount'].to_f / 10_000).round * 10_000 }
      
#       # Find transactions that occur monthly with similar amounts
#       potential_salaries = amount_groups.select do |amount_range, transactions|
#         transactions.length >= 3 && amount_range >= 30_000 # At least 3 occurrences, minimum amount
#       end.values.flatten
      
#       potential_salaries
#     end
    
#     def categorize_spending(debit_transactions)
#       categories = {
#         'ATM Withdrawals' => [],
#         'Transfers' => [],
#         'Bills & Utilities' => [],
#         'Shopping' => [],
#         'Other' => []
#       }
      
#       debit_transactions.each do |transaction|
#         narration = transaction['narration']&.downcase || ''
        
#         case narration
#         when /atm|withdrawal|cash/
#           categories['ATM Withdrawals'] << transaction
#         when /transfer|trf|tfr/
#           categories['Transfers'] << transaction
#         when /bill|utility|electricity|water|internet|phone/
#           categories['Bills & Utilities'] << transaction
#         when /pos|purchase|payment|shop/
#           categories['Shopping'] << transaction
#         else
#           categories['Other'] << transaction
#         end
#       end
      
#       categories.transform_values { |txns| txns.sum { |t| t['amount'].to_f } }
#     end
    
#     def identify_income_sources(credit_transactions)
#       sources = {}
      
#       credit_transactions.each do |transaction|
#         narration = transaction['narration'] || 'Unknown'
#         amount = transaction['amount'].to_f
        
#         # Group similar narrations
#         key = if narration.match?(/salary|sal|wage|pay/i)
#                 'Salary'
#               elsif narration.match?(/transfer|trf/i)
#                 'Transfers'
#               elsif narration.match?(/deposit|cash/i)
#                 'Cash Deposits'
#               else
#                 'Other Income'
#               end
        
#         sources[key] ||= { count: 0, total: 0 }
#         sources[key][:count] += 1
#         sources[key][:total] += amount
#       end
      
#       sources
#     end
    
#     def identify_frequent_merchants(debit_transactions)
#       merchant_frequency = {}
      
#       debit_transactions.each do |transaction|
#         # Extract merchant name from narration
#         narration = transaction['narration'] || 'Unknown Merchant'
        
#         # Simple merchant identification
#         merchant = if narration.match?(/ATM/i)
#                      'ATM'
#                    elsif narration.match?(/POS/i)
#                      'POS Transaction'
#                    else
#                      narration.split('/').first&.strip || narration
#                    end
        
#         merchant_frequency[merchant] ||= { count: 0, total: 0 }
#         merchant_frequency[merchant][:count] += 1
#         merchant_frequency[merchant][:total] += transaction['amount'].to_f
#       end
      
#       # Return top 5 merchants by frequency
#       merchant_frequency.sort_by { |_, data| -data[:count] }.first(5).to_h
#     end
    
#     def count_overdraft_incidents
#       @transactions.count { |t| (t['balance_after'] || 0).to_f < 0 }
#     end
    
#     def count_bounce_incidents
#       # Look for bounce-related narrations
#       @transactions.count { |t| (t['narration'] || '').match?(/bounce|returned|insufficient|failed/i) }
#     end
    
#     def calculate_average_balance
#       balances = @transactions.map { |t| (t['balance_after'] || 0).to_f }
#       return 0 if balances.empty?
      
#       balances.sum / balances.length
#     end
    
#     def calculate_balance_volatility
#       balances = @transactions.map { |t| (t['balance_after'] || 0).to_f }
#       return 0 if balances.length < 2
      
#       mean = balances.sum / balances.length
#       variance = balances.sum { |b| (b - mean) ** 2 } / balances.length
#       Math.sqrt(variance)
#     end
    
#     def calculate_transaction_frequency
#       return 0 if @transactions.empty?
      
#       # Transactions per month
#       months = [(Time.current - analysis_start_date) / 1.month, 1].max
#       @transactions.length / months
#     end
    
#     def calculate_debt_to_income_ratio
#       income_analysis = analyze_income
#       spending_analysis = analyze_spending
      
#       monthly_income = income_analysis[:average_monthly_income]
#       monthly_spending = spending_analysis[:average_monthly_spending]
      
#       return 0 if monthly_income <= 0
      
#       # Focus on debt-related spending (loans, credit cards, etc.)
#       debt_spending = @transactions.select do |t|
#         t['debit_credit'] == 'DEBIT' && 
#         (t['narration'] || '').match?(/loan|credit|debt|installment|mortgage/i)
#       end
      
#       monthly_debt_payments = debt_spending.sum { |t| t['amount'].to_f } / 6.0 # 6 months average
      
#       monthly_debt_payments / monthly_income
#     end
    
#     def calculate_savings_rate
#       income_analysis = analyze_income
#       spending_analysis = analyze_spending
      
#       monthly_income = income_analysis[:average_monthly_income]
#       monthly_spending = spending_analysis[:average_monthly_spending]
      
#       return 0 if monthly_income <= 0
      
#       savings = monthly_income - monthly_spending
#       savings > 0 ? savings / monthly_income : 0
#     end
    
#     def calculate_income_consistency(monthly_credits)
#       return 0 if monthly_credits.empty?
      
#       amounts = monthly_credits.values
#       mean = amounts.sum / amounts.length
      
#       return 1 if amounts.length == 1
      
#       # Calculate coefficient of variation (lower is more consistent)
#       variance = amounts.sum { |amount| (amount - mean) ** 2 } / amounts.length
#       std_dev = Math.sqrt(variance)
      
#       return 1 if mean == 0
      
#       coefficient_of_variation = std_dev / mean
      
#       # Convert to consistency score (0-1, where 1 is perfectly consistent)
#       [1 - coefficient_of_variation, 0].max
#     end
    
#     def calculate_spending_consistency(monthly_debits)
#       return 0 if monthly_debits.empty?
      
#       amounts = monthly_debits.values
#       mean = amounts.sum / amounts.length
      
#       return 1 if amounts.length == 1
      
#       # Calculate coefficient of variation
#       variance = amounts.sum { |amount| (amount - mean) ** 2 } / amounts.length
#       std_dev = Math.sqrt(variance)
      
#       return 1 if mean == 0
      
#       coefficient_of_variation = std_dev / mean
      
#       # Convert to consistency score
#       [1 - coefficient_of_variation, 0].max
#     end
    
#     def calculate_oldest_account_age
#       # Since we don't have account creation dates from the API,
#       # we'll estimate based on earliest transaction
#       return 0 if @transactions.empty?
      
#       earliest_date = @transactions.min_by do |t|
#         Date.parse(t['transaction_time'] || t['value_date'])
#       end
      
#       if earliest_date
#         date = Date.parse(earliest_date['transaction_time'] || earliest_date['value_date'])
#         ((Time.current.to_date - date) / 30).round # Approximate months
#       else
#         0
#       end
#     end
#   end
# app/services/api_credit_analysis_service.rb
class ApiCreditAnalysisService
    def initialize(user, financial_data)
      @user = user
      @financial_data = financial_data
      @transactions = financial_data[:all_transactions]
      @accounts = financial_data[:accounts]
      @analysis_date = Time.current
    end
    
    def perform_analysis
      return default_analysis if @transactions.empty?
      
      analysis_data = {
        transaction_count: @transactions.length,
        account_count: @accounts.length,
        analysis_period: {
          from: analysis_start_date,
          to: @analysis_date,
          months: 6
        },
        income_analysis: analyze_income,
        spending_analysis: analyze_spending,
        financial_behavior: analyze_financial_behavior,
        risk_factors: assess_risk_factors,
        account_stability: analyze_account_stability,
        calculated_at: @analysis_date
      }
      
      score = calculate_composite_score(analysis_data)
      grade = determine_grade(score)
      
      {
        score: score,
        grade: grade,
        analysis_data: analysis_data
      }
    end
    
    private
    
    def default_analysis
      {
        score: 300, # Minimum score
        grade: 'Poor',
        analysis_data: {
          transaction_count: 0,
          account_count: 0,
          error: 'Insufficient transaction data for analysis'
        }
      }
    end
    
    def analysis_start_date
      @analysis_start_date ||= begin
        if @transactions.any?
          earliest_transaction = @transactions.min_by { |t| Date.parse(t['transaction_time'] || t['value_date']) }
          Date.parse(earliest_transaction['transaction_time'] || earliest_transaction['value_date'])
        else
          6.months.ago.to_date
        end
      end
    end
    
    def analyze_income
      credit_transactions = @transactions.select { |t| t['debit_credit'] == 'CREDIT' }
      
      monthly_credits = group_transactions_by_month(credit_transactions)
      
      # Identify salary-like transactions (regular amounts, monthly frequency)
      potential_salaries = identify_salary_transactions(credit_transactions)
      
      {
        total_credits: credit_transactions.sum { |t| t['amount'].to_f },
        average_monthly_income: monthly_credits.values.sum / [monthly_credits.length, 1].max,
        salary_transactions: potential_salaries.length,
        estimated_monthly_salary: potential_salaries.sum { |t| t['amount'].to_f } / [potential_salaries.length, 1].max,
        income_consistency: calculate_income_consistency(monthly_credits),
        income_sources: identify_income_sources(credit_transactions)
      }
    end
    
    def analyze_spending
      debit_transactions = @transactions.select { |t| t['debit_credit'] == 'DEBIT' }
      
      monthly_debits = group_transactions_by_month(debit_transactions)
      
      spending_categories = categorize_spending(debit_transactions)
      
      {
        total_spending: debit_transactions.sum { |t| t['amount'].to_f },
        average_monthly_spending: monthly_debits.values.sum / [monthly_debits.length, 1].max,
        spending_consistency: calculate_spending_consistency(monthly_debits),
        spending_categories: spending_categories,
        largest_expense: debit_transactions.max_by { |t| t['amount'].to_f },
        frequent_merchants: identify_frequent_merchants(debit_transactions)
      }
    end
    
    def analyze_financial_behavior
      {
        overdraft_incidents: count_overdraft_incidents,
        bounce_incidents: count_bounce_incidents,
        average_balance: calculate_average_balance,
        balance_volatility: calculate_balance_volatility,
        transaction_frequency: calculate_transaction_frequency,
        debt_to_income_ratio: calculate_debt_to_income_ratio,
        savings_rate: calculate_savings_rate
      }
    end
    
    def assess_risk_factors
      risk_factors = []
      
      # High debt-to-income ratio
      dti = calculate_debt_to_income_ratio
      risk_factors << "High debt-to-income ratio (#{(dti * 100).round(1)}%)" if dti > 0.6
      
      # Frequent overdrafts
      overdrafts = count_overdraft_incidents
      risk_factors << "Frequent overdrafts (#{overdrafts} incidents)" if overdrafts > 5
      
      # Low average balance
      avg_balance = calculate_average_balance
      risk_factors << "Low average balance (₦#{avg_balance.round(2)})" if avg_balance < 10_000
      
      # Irregular income
      income_analysis = analyze_income
      if income_analysis[:income_consistency] < 0.7
        risk_factors << "Irregular income pattern"
      end
      
      # High spending volatility
      spending_analysis = analyze_spending
      if spending_analysis[:spending_consistency] < 0.6
        risk_factors << "Inconsistent spending patterns"
      end
      
      risk_factors
    end
    
    def analyze_account_stability
      {
        oldest_account_age: calculate_oldest_account_age,
        account_diversity: @accounts.length,
        total_relationships: @accounts.map { |a| a['bank_name'] || 'Unknown' }.uniq.length,
        account_status: @accounts.map { |a| a['status'] || 'ACTIVE' }.uniq
      }
    end
    
    def calculate_composite_score(analysis_data)
      # Base score
      score = 300
      
      # Income factors (up to 200 points)
      income_score = calculate_income_score(analysis_data[:income_analysis])
      score += income_score
      
      # Financial behavior (up to 150 points)
      behavior_score = calculate_behavior_score(analysis_data[:financial_behavior])
      score += behavior_score
      
      # Account stability (up to 100 points)
      stability_score = calculate_stability_score(analysis_data[:account_stability])
      score += stability_score
      
      # Risk factors (deductions)
      risk_deductions = analysis_data[:risk_factors].length * 25
      score -= risk_deductions
      
      # Transaction volume bonus (up to 50 points)
      transaction_bonus = [analysis_data[:transaction_count] / 10, 50].min
      score += transaction_bonus
      
      # Ensure score is within valid range
      [[score, 300].max, 850].min
    end
    
    def calculate_income_score(income_analysis)
      score = 0
      
      # Monthly income score (up to 100 points)
      monthly_income = income_analysis[:average_monthly_income]
      score += case monthly_income
                when 0..50_000 then (monthly_income / 50_000.0 * 40).round
                when 50_000..150_000 then 40 + ((monthly_income - 50_000) / 100_000.0 * 40).round
                when 150_000..500_000 then 80 + ((monthly_income - 150_000) / 350_000.0 * 20).round
                else 100
                end
      
      # Income consistency (up to 100 points)
      consistency_score = (income_analysis[:income_consistency] * 100).round
      score += consistency_score
      
      score
    end
    
    def calculate_behavior_score(behavior_analysis)
      score = 0
      
      # Overdraft penalty
      score -= behavior_analysis[:overdraft_incidents] * 10
      
      # Balance management (up to 60 points)
      avg_balance = behavior_analysis[:average_balance]
      balance_score = case avg_balance
                      when 0..10_000 then (avg_balance / 10_000.0 * 20).round
                      when 10_000..50_000 then 20 + ((avg_balance - 10_000) / 40_000.0 * 25).round
                      when 50_000..200_000 then 45 + ((avg_balance - 50_000) / 150_000.0 * 15).round
                      else 60
                      end
      score += balance_score
      
      # Transaction frequency (up to 40 points)
      frequency_score = [behavior_analysis[:transaction_frequency] / 10, 40].min
      score += frequency_score
      
      # Savings rate bonus (up to 50 points)
      savings_rate = behavior_analysis[:savings_rate]
      savings_score = (savings_rate * 100).round if savings_rate > 0
      score += [savings_score || 0, 50].min
      
      [score, 150].min
    end
    
    def calculate_stability_score(stability_analysis)
      score = 0
      
      # Account age (up to 50 points)
      age_months = stability_analysis[:oldest_account_age]
      age_score = [age_months * 2, 50].min
      score += age_score
      
      # Account diversity (up to 30 points)
      diversity_score = [stability_analysis[:account_diversity] * 10, 30].min
      score += diversity_score
      
      # Bank relationships (up to 20 points)
      relationship_score = [stability_analysis[:total_relationships] * 10, 20].min
      score += relationship_score
      
      score
    end
    
    def determine_grade(score)
      case score
      when 750..850 then 'Excellent'
      when 700..749 then 'Very Good'
      when 650..699 then 'Good'
      when 600..649 then 'Fair'
      when 550..599 then 'Poor'
      else 'Very Poor'
      end
    end
    
    # Helper methods
    
    def group_transactions_by_month(transactions)
      transactions.group_by do |transaction|
        date = Date.parse(transaction['transaction_time'] || transaction['value_date'])
        date.strftime('%Y-%m')
      end.transform_values { |txns| txns.sum { |t| t['amount'].to_f } }
    end
    
    def identify_salary_transactions(credit_transactions)
      # Group by amount ranges and frequency
      amount_groups = credit_transactions.group_by { |t| (t['amount'].to_f / 10_000).round * 10_000 }
      
      # Find transactions that occur monthly with similar amounts
      potential_salaries = amount_groups.select do |amount_range, transactions|
        transactions.length >= 3 && amount_range >= 30_000 # At least 3 occurrences, minimum amount
      end.values.flatten
      
      potential_salaries
    end
    
    def categorize_spending(debit_transactions)
      categories = {
        'ATM Withdrawals' => [],
        'Transfers' => [],
        'Bills & Utilities' => [],
        'Shopping' => [],
        'Other' => []
      }
      
      debit_transactions.each do |transaction|
        narration = transaction['narration']&.downcase || ''
        
        case narration
        when /atm|withdrawal|cash/
          categories['ATM Withdrawals'] << transaction
        when /transfer|trf|tfr/
          categories['Transfers'] << transaction
        when /bill|utility|electricity|water|internet|phone/
          categories['Bills & Utilities'] << transaction
        when /pos|purchase|payment|shop/
          categories['Shopping'] << transaction
        else
          categories['Other'] << transaction
        end
      end
      
      categories.transform_values { |txns| txns.sum { |t| t['amount'].to_f } }
    end
    
    def identify_income_sources(credit_transactions)
      sources = {}
      
      credit_transactions.each do |transaction|
        narration = transaction['narration'] || 'Unknown'
        amount = transaction['amount'].to_f
        
        # Group similar narrations
        key = if narration.match?(/salary|sal|wage|pay/i)
                'Salary'
              elsif narration.match?(/transfer|trf/i)
                'Transfers'
              elsif narration.match?(/deposit|cash/i)
                'Cash Deposits'
              else
                'Other Income'
              end
        
        sources[key] ||= { count: 0, total: 0 }
        sources[key][:count] += 1
        sources[key][:total] += amount
      end
      
      sources
    end
    
    def identify_frequent_merchants(debit_transactions)
      merchant_frequency = {}
      
      debit_transactions.each do |transaction|
        # Extract merchant name from narration
        narration = transaction['narration'] || 'Unknown Merchant'
        
        # Simple merchant identification
        merchant = if narration.match?(/ATM/i)
                     'ATM'
                   elsif narration.match?(/POS/i)
                     'POS Transaction'
                   else
                     narration.split('/').first&.strip || narration
                   end
        
        merchant_frequency[merchant] ||= { count: 0, total: 0 }
        merchant_frequency[merchant][:count] += 1
        merchant_frequency[merchant][:total] += transaction['amount'].to_f
      end
      
      # Return top 5 merchants by frequency
      merchant_frequency.sort_by { |_, data| -data[:count] }.first(5).to_h
    end
    
    def count_overdraft_incidents
      @transactions.count { |t| (t['balance_after'] || 0).to_f < 0 }
    end
    
    def count_bounce_incidents
      # Look for bounce-related narrations
      @transactions.count { |t| (t['narration'] || '').match?(/bounce|returned|insufficient|failed/i) }
    end
    
    def calculate_average_balance
      balances = @transactions.map { |t| (t['balance_after'] || 0).to_f }
      return 0 if balances.empty?
      
      balances.sum / balances.length
    end
    
    def calculate_balance_volatility
      balances = @transactions.map { |t| (t['balance_after'] || 0).to_f }
      return 0 if balances.length < 2
      
      mean = balances.sum / balances.length
      variance = balances.sum { |b| (b - mean) ** 2 } / balances.length
      Math.sqrt(variance)
    end
    
    def calculate_transaction_frequency
      return 0 if @transactions.empty?
      
      # Calculate transactions per month
      start_date = analysis_start_date
      end_date = Time.current.to_date
      
      months = ((end_date - start_date).to_f / 30).round
      months = [months, 1].max # At least 1 month
      
      @transactions.length.to_f / months
    end
    
    def calculate_debt_to_income_ratio
      income_analysis = analyze_income
      spending_analysis = analyze_spending
      
      monthly_income = income_analysis[:average_monthly_income]
      monthly_spending = spending_analysis[:average_monthly_spending]
      
      return 0 if monthly_income <= 0
      
      # Focus on debt-related spending (loans, credit cards, etc.)
      debt_spending = @transactions.select do |t|
        t['debit_credit'] == 'DEBIT' && 
        (t['narration'] || '').match?(/loan|credit|debt|installment|mortgage/i)
      end
      
      monthly_debt_payments = debt_spending.sum { |t| t['amount'].to_f } / 6.0 # 6 months average
      
      monthly_debt_payments / monthly_income
    end
    
    def calculate_savings_rate
      income_analysis = analyze_income
      spending_analysis = analyze_spending
      
      monthly_income = income_analysis[:average_monthly_income]
      monthly_spending = spending_analysis[:average_monthly_spending]
      
      return 0 if monthly_income <= 0
      
      savings = monthly_income - monthly_spending
      savings > 0 ? savings / monthly_income : 0
    end
    
    def calculate_income_consistency(monthly_credits)
      return 0 if monthly_credits.empty?
      
      amounts = monthly_credits.values
      mean = amounts.sum / amounts.length
      
      return 1 if amounts.length == 1
      
      # Calculate coefficient of variation (lower is more consistent)
      variance = amounts.sum { |amount| (amount - mean) ** 2 } / amounts.length
      std_dev = Math.sqrt(variance)
      
      return 1 if mean == 0
      
      coefficient_of_variation = std_dev / mean
      
      # Convert to consistency score (0-1, where 1 is perfectly consistent)
      [1 - coefficient_of_variation, 0].max
    end
    
    def calculate_spending_consistency(monthly_debits)
      return 0 if monthly_debits.empty?
      
      amounts = monthly_debits.values
      mean = amounts.sum / amounts.length
      
      return 1 if amounts.length == 1
      
      # Calculate coefficient of variation
      variance = amounts.sum { |amount| (amount - mean) ** 2 } / amounts.length
      std_dev = Math.sqrt(variance)
      
      return 1 if mean == 0
      
      coefficient_of_variation = std_dev / mean
      
      # Convert to consistency score
      [1 - coefficient_of_variation, 0].max
    end
    
    def calculate_oldest_account_age
      # Since we don't have account creation dates from the API,
      # we'll estimate based on earliest transaction
      return 0 if @transactions.empty?
      
      earliest_transaction = @transactions.min_by do |t|
        Date.parse(t['transaction_time'] || t['value_date'])
      end
      
      if earliest_transaction
        date = Date.parse(earliest_transaction['transaction_time'] || earliest_transaction['value_date'])
        months_diff = ((Time.current.to_date - date).to_f / 30).round # Approximate months
        [months_diff, 0].max
      else
        0
      end
    end
end