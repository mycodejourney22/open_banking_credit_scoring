# app/services/credit_scoring_service.rb
class CreditScoringService
    CURRENT_MODEL_VERSION = '1.0'
  
    def initialize(user)
      @user = user
      @financial_profile = user.financial_profile
    end
  
    def calculate
      return nil unless @financial_profile
  
      features = extract_features
      score = calculate_base_score(features)
      
      # Apply adjustments
      score = apply_behavioral_adjustments(score, features)
      score = apply_risk_adjustments(score, features)
      
      # Ensure score is within valid range
      final_score = [[score, 300].max, 850].min
  
      create_credit_score(final_score, features)
    end
  
    private
  
    def extract_features
      {
        # Income stability
        avg_monthly_income: @financial_profile.average_monthly_income || 0,
        income_volatility: calculate_income_volatility,
        
        # Spending behavior
        avg_monthly_expenses: @financial_profile.average_monthly_expenses || 0,
        savings_rate: @financial_profile.savings_rate || 0,
        expense_volatility: @financial_profile.expense_volatility || 0,
        
        # Debt management
        debt_to_income_ratio: @financial_profile.debt_to_income_ratio || 0,
        
        # Banking behavior
        transaction_frequency: @financial_profile.transaction_frequency || 0,
        account_age: calculate_account_age,
        bounced_transactions: count_bounced_transactions,
        
        # Demographics
        age: calculate_age,
        employment_status: @user.employment_status,
        declared_income: @user.declared_income || 0
      }
    end
  
    def calculate_base_score(features)
      # Base score calculation using weighted factors
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
      
      # Banking behavior factor (0-70 points)
      behavior_score = calculate_banking_behavior_score(features)
      score += behavior_score
      
      # Stability factor (0-50 points)
      stability_score = calculate_stability_score(features)
      score += stability_score
  
      score
    end
  
    def calculate_banking_behavior_score(features)
      score = 0
      
      # Transaction frequency (0-25 points)
      frequency_score = [features[:transaction_frequency] / 100.0 * 25, 25].min
      score += frequency_score
      
      # Account age (0-20 points)
      age_score = [features[:account_age] / 24.0 * 20, 20].min  # 24 months = max points
      score += age_score
      
      # Bounced transactions penalty (0-25 points)
      bounce_penalty = [features[:bounced_transactions] * 5, 25].min
      score += (25 - bounce_penalty)
      
      score
    end
  
    def calculate_stability_score(features)
      score = 0
      
      # Income volatility (0-25 points) - lower volatility is better
      income_volatility_score = features[:income_volatility] > 0.3 ? 0 : (1 - features[:income_volatility]) * 25
      score += income_volatility_score
      
      # Expense volatility (0-25 points) - lower volatility is better
      expense_volatility_score = features[:expense_volatility] > 0.3 ? 0 : (1 - features[:expense_volatility]) * 25
      score += expense_volatility_score
      
      score
    end
  
    def apply_behavioral_adjustments(score, features)
      # Positive adjustments
      score += 20 if features[:savings_rate] > 0.2  # Good saver bonus
      score += 15 if features[:transaction_frequency] > 80  # Active user bonus
      score += 10 if features[:account_age] > 12  # Loyalty bonus
      
      # Negative adjustments
      score -= 30 if features[:bounced_transactions] > 5  # Poor payment history penalty
      score -= 25 if features[:debt_to_income_ratio] > 0.5  # High debt penalty
      score -= 20 if features[:expense_volatility] > 0.4  # Unstable spending penalty
      
      score
    end
  
    def apply_risk_adjustments(score, features)
      # Age-based adjustments
      case features[:age]
      when 18..25
        score -= 10  # Young adult risk
      when 26..35
        score += 5   # Prime age bonus
      when 36..50
        score += 10  # Mature age bonus
      when 51..65
        score += 5   # Stable age
      else
        score -= 5   # Senior risk
      end
      
      # Employment status adjustments
      case features[:employment_status]
      when 'employed'
        score += 15
      when 'self_employed'
        score += 5
      when 'unemployed'
        score -= 20
      when 'student'
        score -= 10
      end
      
      score
    end
  
    def create_credit_score(score, features)
      default_probability = calculate_default_probability(score)
      
      @user.credit_scores.create!(
        score: score.round,
        default_probability: default_probability,
        score_breakdown: generate_score_breakdown(features),
        risk_factors: identify_risk_factors(features),
        improvement_suggestions: generate_improvement_suggestions(features),
        model_version: CURRENT_MODEL_VERSION,
        calculated_at: Time.current
      )
    end
  
    def calculate_default_probability(score)
      # Sigmoid function to convert score to probability
      # Lower scores = higher default probability
      normalized_score = (score - 300) / 550.0  # Normalize to 0-1
      1.0 / (1.0 + Math.exp(5 * (normalized_score - 0.5)))
    end
  
    def generate_score_breakdown(features)
      {
        income_stability: calculate_income_component_score(features),
        spending_behavior: calculate_spending_component_score(features),
        debt_management: calculate_debt_component_score(features),
        banking_behavior: calculate_banking_behavior_score(features),
        demographics: calculate_demographic_component_score(features)
      }
    end
  
    def identify_risk_factors(features)
      risks = []
      
      risks << 'High debt-to-income ratio' if features[:debt_to_income_ratio] > 0.4
      risks << 'Low savings rate' if features[:savings_rate] < 0.1
      risks << 'Irregular income' if features[:income_volatility] > 0.3
      risks << 'Unstable spending patterns' if features[:expense_volatility] > 0.3
      risks << 'Frequent bounced transactions' if features[:bounced_transactions] > 3
      risks << 'Low banking activity' if features[:transaction_frequency] < 20
      risks << 'New banking relationship' if features[:account_age] < 6
      
      risks
    end
  
    def generate_improvement_suggestions(features)
      suggestions = []
      
      suggestions << 'Increase your savings rate to improve financial stability' if features[:savings_rate] < 0.15
      suggestions << 'Reduce your debt-to-income ratio by paying down existing debts' if features[:debt_to_income_ratio] > 0.3
      suggestions << 'Maintain consistent banking activity to build credit history' if features[:transaction_frequency] < 30
      suggestions << 'Avoid bounced transactions by maintaining adequate account balances' if features[:bounced_transactions] > 1
      suggestions << 'Stabilize your income sources for better creditworthiness' if features[:income_volatility] > 0.25
      
      suggestions
    end
  
    # Helper methods for feature extraction
    def calculate_income_volatility
      return 0 unless @user.transactions.credits.exists?
      
      monthly_incomes = @user.transactions.credits
                             .group_by_month(:transaction_date, last: 12)
                             .sum(:amount)
                             .values
      
      return 0 if monthly_incomes.length < 3
      
      mean = monthly_incomes.sum / monthly_incomes.length.to_f
      variance = monthly_incomes.sum { |income| (income - mean) ** 2 } / monthly_incomes.length.to_f
      standard_deviation = Math.sqrt(variance)
      
      mean > 0 ? standard_deviation / mean : 0
    end
  
    def calculate_account_age
      oldest_connection = @user.bank_connections.minimum(:created_at)
      return 0 unless oldest_connection
      
      ((Time.current - oldest_connection) / 1.month).round
    end
  
    def count_bounced_transactions
      # Count transactions with bounce-related descriptions
      @user.transactions.where(
        "description ILIKE ? OR description ILIKE ? OR description ILIKE ?",
        '%bounce%', '%returned%', '%insufficient%'
      ).count
    end
  
    def calculate_age
      return 0 unless @user.date_of_birth
      
      ((Time.current - @user.date_of_birth.to_time) / 1.year).round
    end
  
    # Component score calculations
    def calculate_income_component_score(features)
      score = 0
      score += [Math.log10(features[:avg_monthly_income] / 50_000.0) * 25 + 50, 75].min if features[:avg_monthly_income] > 0
      score += (1 - features[:income_volatility]) * 25 if features[:income_volatility] < 0.3
      score
    end
  
    def calculate_spending_component_score(features)
      score = 0
      score += features[:savings_rate] * 50
      score += (1 - features[:expense_volatility]) * 25 if features[:expense_volatility] < 0.3
      score
    end
  
    def calculate_debt_component_score(features)
      score = 0
      score += (1 - features[:debt_to_income_ratio]) * 50 if features[:debt_to_income_ratio] < 0.4
      score
    end
  
    def calculate_demographic_component_score(features)
      score = 0
      
      # Age factor
      case features[:age]
      when 26..50
        score += 15
      when 18..25, 51..65
        score += 10
      else
        score += 5
      end
      
      # Employment status
      case features[:employment_status]
      when 'employed'
        score += 20
      when 'self_employed'
        score += 15
      when 'unemployed'
        score += 0
      when 'student'
        score += 5
      end
      
      score
    end
  end