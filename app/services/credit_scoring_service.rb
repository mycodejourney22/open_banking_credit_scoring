# app/services/credit_scoring_service.rb (Fixed Version)
class CreditScoringService
    CURRENT_MODEL_VERSION = '1.0'
  
    def initialize(user)
      @user = user
      @financial_profile = user.financial_profile || user.ensure_financial_profile!
      @transactions = user.transactions.order(:transaction_date)
    end
  
    def calculate_score
      return { success: false, error: 'No transaction data available' } if @transactions.empty?
  
      begin
        # Create financial profile if it doesn't exist
        unless @financial_profile
          @financial_profile = @user.ensure_financial_profile!
        end
  
        # Calculate features from transaction data
        features = extract_features_from_transactions
        
        # Calculate base score
        score = calculate_base_score(features)
        
        # Apply adjustments
        score = apply_behavioral_adjustments(score, features)
        score = apply_risk_adjustments(score, features)
        
        # Ensure score is within valid range (300-850)
        final_score = [[score, 300].max, 850].min.round
  
        # Create credit score record
        credit_score = create_credit_score(final_score, features)
        
        { success: true, credit_score: credit_score }
      rescue => e
        Rails.logger.error "Credit scoring failed: #{e.message}"
        { success: false, error: e.message }
      end
    end
  
    private
  
    def extract_features_from_transactions
      # Analyze last 6 months of transactions for more accurate assessment
      recent_transactions = @transactions.where('transaction_date >= ?', 6.months.ago)
      
      credit_transactions = recent_transactions.where(transaction_type: 'credit')
      debit_transactions = recent_transactions.where(transaction_type: 'debit')
  
      # Calculate monthly income (from credit transactions)
      monthly_income = calculate_monthly_income(credit_transactions)
      
      # Calculate monthly expenses (from debit transactions)
      monthly_expenses = calculate_monthly_expenses(debit_transactions)
      
      # Calculate other metrics
      {
        avg_monthly_income: monthly_income,
        avg_monthly_expenses: monthly_expenses,
        savings_rate: monthly_income > 0 ? [(monthly_income - monthly_expenses) / monthly_income, 0].max : 0,
        debt_to_income_ratio: calculate_debt_to_income_ratio(debit_transactions, monthly_income),
        transaction_frequency: recent_transactions.count,
        account_age_months: calculate_account_age_months,
        bounced_transactions: count_bounced_transactions,
        income_stability: calculate_income_stability(credit_transactions),
        spending_volatility: calculate_spending_volatility(debit_transactions),
        age: calculate_age,
        employment_status: @user.employment_status,
        declared_income: @user.declared_income || 0,
        total_transactions: @transactions.count
      }
    end
  
    def calculate_monthly_income(credit_transactions)
      return 0 if credit_transactions.empty?
      
      # Look for salary patterns
      salary_transactions = credit_transactions.where(
        "description ILIKE ? OR description ILIKE ? OR description ILIKE ?",
        '%salary%', '%payroll%', '%wages%'
      )
      
      if salary_transactions.any?
        # Use salary transactions if available
        salary_transactions.sum(:amount) / 6.0
      else
        # Use average of all credit transactions
        credit_transactions.sum(:amount) / 6.0
      end
    end
  
    def calculate_monthly_expenses(debit_transactions)
      return 0 if debit_transactions.empty?
      debit_transactions.sum('ABS(amount)') / 6.0
    end
  
    def calculate_debt_to_income_ratio(debit_transactions, monthly_income)
      return 0 if monthly_income <= 0
      
      # Look for debt-related transactions
      debt_transactions = debit_transactions.where(
        "description ILIKE ? OR description ILIKE ? OR description ILIKE ?",
        '%loan%', '%credit%', '%mortgage%'
      )
      
      monthly_debt_payments = debt_transactions.sum('ABS(amount)') / 6.0
      monthly_debt_payments / monthly_income
    end
  
    def calculate_account_age_months
      oldest_connection = @user.bank_connections.minimum(:created_at)
      return 0 unless oldest_connection
      
      ((Time.current - oldest_connection) / 1.month).round
    end
  
    def count_bounced_transactions
      # Count transactions with negative balance_after as potential bounces
      @transactions.where('balance_after < 0').count
    end
  
    def calculate_income_stability(credit_transactions)
      return 0 if credit_transactions.count < 3
      
      monthly_amounts = credit_transactions.group_by_month(:transaction_date, last: 6)
                                         .sum(:amount)
                                         .values
      
      return 0 if monthly_amounts.empty?
      
      mean = monthly_amounts.sum / monthly_amounts.length.to_f
      variance = monthly_amounts.sum { |amount| (amount - mean) ** 2 } / monthly_amounts.length.to_f
      
      # Return stability score (lower variance = higher stability)
      mean > 0 ? [1 - (Math.sqrt(variance) / mean), 0].max : 0
    end
  
    def calculate_spending_volatility(debit_transactions)
      return 0 if debit_transactions.count < 3
      
      monthly_amounts = debit_transactions.group_by_month(:transaction_date, last: 6)
                                        .sum('ABS(amount)')
                                        .values
      
      return 0 if monthly_amounts.empty?
      
      mean = monthly_amounts.sum / monthly_amounts.length.to_f
      variance = monthly_amounts.sum { |amount| (amount - mean) ** 2 } / monthly_amounts.length.to_f
      
      mean > 0 ? Math.sqrt(variance) / mean : 0
    end
  
    def calculate_base_score(features)
      score = 300  # Minimum score
      
      # Income factor (0-150 points)
      if features[:avg_monthly_income] > 0
        income_score = [Math.log10(features[:avg_monthly_income] / 50_000.0) * 50 + 100, 150].min
        score += [income_score, 0].max
      end
      
      # Savings rate factor (0-100 points)
      savings_score = features[:savings_rate] * 100
      score += [savings_score, 100].min
      
      # Debt management factor (0-80 points)
      debt_score = features[:debt_to_income_ratio] > 0.4 ? 0 : (1 - features[:debt_to_income_ratio]) * 80
      score += debt_score
      
      # Account age factor (0-60 points)
      age_score = [features[:account_age_months] / 24.0 * 60, 60].min
      score += age_score
      
      # Transaction frequency factor (0-40 points)
      frequency_score = [features[:transaction_frequency] / 100.0 * 40, 40].min
      score += frequency_score
      
      score
    end
  
    def apply_behavioral_adjustments(score, features)
      # Income stability adjustment (-30 to +30 points)
      stability_adjustment = (features[:income_stability] - 0.5) * 60
      score += stability_adjustment
      
      # Spending volatility adjustment (-20 to +20 points)
      volatility_adjustment = (0.3 - features[:spending_volatility]) * 60
      score += [volatility_adjustment, 20].min
      
      score
    end
  
    def apply_risk_adjustments(score, features)
      # Bounced transactions penalty
      bounce_penalty = features[:bounced_transactions] * 10
      score -= bounce_penalty
      
      # Age factor (younger = slightly riskier)
      if features[:age] < 25
        score -= 20
      elsif features[:age] > 50
        score += 10
      end
      
      # Employment status adjustment
      case features[:employment_status]
      when 'employed'
        score += 20
      when 'self_employed'
        score += 10
      when 'unemployed'
        score -= 50
      when 'student'
        score -= 10
      end
      
      score
    end
  
    def calculate_age
      return 30 unless @user.date_of_birth  # Default age if not provided
      ((Time.current - @user.date_of_birth.to_time) / 1.year).round
    end
  
    def create_credit_score(score, features)
      grade = determine_grade(score)
      risk_level = determine_risk_level(score)
      
      @user.credit_scores.create!(
        score: score,
        grade: grade,
        risk_level: risk_level,
        default_probability: calculate_default_probability(score),
        score_breakdown: build_score_breakdown(features),
        risk_factors: identify_risk_factors(features),
        improvement_suggestions: generate_improvement_suggestions(features),
        analysis_data: features.to_json,
        model_version: CURRENT_MODEL_VERSION,
        calculated_at: Time.current
      )
    end
  
    def determine_grade(score)
      case score
      when 800..850 then 'A+'
      when 740..799 then 'A'
      when 670..739 then 'B+'
      when 580..669 then 'B'
      when 500..579 then 'C'
      when 400..499 then 'D'
      else 'F'
      end
    end
  
    def determine_risk_level(score)
      case score
      when 750..850 then 'low'
      when 650..749 then 'medium'
      when 550..649 then 'high'
      else 'very_high'
      end
    end
  
    def calculate_default_probability(score)
      # Simple model: higher score = lower default probability
      base_probability = 0.5
      score_factor = (score - 300) / 550.0  # Normalize to 0-1
      adjusted_probability = base_probability * (1 - score_factor)
      
      [[adjusted_probability, 0.01].max, 0.5].min  # Between 1% and 50%
    end
  
    def build_score_breakdown(features)
      {
        income_score: [features[:avg_monthly_income] / 1000, 150].min.round,
        savings_score: (features[:savings_rate] * 100).round,
        debt_score: ((1 - features[:debt_to_income_ratio]) * 80).round,
        account_age_score: [features[:account_age_months] / 24.0 * 60, 60].min.round,
        frequency_score: [features[:transaction_frequency] / 100.0 * 40, 40].min.round
      }
    end
  
    def identify_risk_factors(features)
      risks = []
      
      risks << "High debt-to-income ratio" if features[:debt_to_income_ratio] > 0.4
      risks << "Low savings rate" if features[:savings_rate] < 0.1
      risks << "Irregular income" if features[:income_stability] < 0.5
      risks << "High spending volatility" if features[:spending_volatility] > 0.3
      risks << "Limited transaction history" if features[:total_transactions] < 50
      risks << "Recent account opening" if features[:account_age_months] < 6
      risks << "Bounced transactions detected" if features[:bounced_transactions] > 0
      
      risks
    end
  
    def generate_improvement_suggestions(features)
      suggestions = []
      
      suggestions << "Increase your savings rate to improve financial stability" if features[:savings_rate] < 0.15
      suggestions << "Reduce debt payments to improve debt-to-income ratio" if features[:debt_to_income_ratio] > 0.3
      suggestions << "Maintain regular banking activity" if features[:transaction_frequency] < 20
      suggestions << "Avoid overdrafts and bounced transactions" if features[:bounced_transactions] > 0
      suggestions << "Build longer banking history for better credit assessment" if features[:account_age_months] < 12
      
      suggestions
    end
  end