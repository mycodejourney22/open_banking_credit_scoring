# app/models/user.rb
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Existing associations
  has_many :bank_connections, dependent: :destroy
  has_many :account_balances, through: :bank_connections
  has_many :transactions, through: :bank_connections
  has_many :bill_payments, through: :bank_connections
  
  # New associations for credit scoring and loans
  has_many :credit_scores, dependent: :destroy
  has_many :loan_applications, dependent: :destroy
  
  # Validations
  validates :first_name, :last_name, presence: true
  validates :phone_number, presence: true, uniqueness: true
  validates :bvn, presence: true, uniqueness: true, length: { is: 11 }
  validates :nin, presence: true, uniqueness: true, length: { is: 11 }
  validates :date_of_birth, presence: true
  validates :employment_status, inclusion: { in: %w[employed self_employed unemployed student retired] }
  validates :declared_income, presence: true, numericality: { greater_than: 0 }

  enum employment_status: {
    employed: 'employed',
    self_employed: 'self_employed',
    unemployed: 'unemployed',
    student: 'student',
    retired: 'retired'
  }

  scope :with_active_connections, -> { joins(:bank_connections).where(bank_connections: { status: 'active' }) }
  scope :with_credit_scores, -> { joins(:credit_scores) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def latest_credit_score
    credit_scores.order(created_at: :desc).first
  end

  def total_bank_balance
    bank_connections.joins(:account_balances)
                   .group('bank_connections.id')
                   .maximum('account_balances.current_balance')
                   .values
                   .sum
  end

  def active_loan_count
    loan_applications.active.count
  end

  def total_disbursed_loans
    loan_applications.where(status: 'disbursed').sum(:amount_approved) || 0
  end

  def eligible_for_loans?
    latest_score = latest_credit_score
    return false unless latest_score
    
    latest_score.score >= 400 && bank_connections.active.any?
  end

  def estimated_monthly_income
    latest_score = latest_credit_score
    return declared_income / 12 unless latest_score&.analysis_data

    latest_score.analysis_data.dig('income_analysis', 'average_monthly_income') || (declared_income / 12)
  end

  def can_calculate_credit_score?
    # User needs at least one active bank connection with some transaction history
    bank_connections.active.any? && 
    transactions.count >= 10 && 
    transactions.where('created_at >= ?', 30.days.ago).any?
  end

  def needs_credit_score_refresh?
    latest_score = latest_credit_score
    return true unless latest_score
    
    latest_score.created_at < 30.days.ago
  end

  def credit_score_status
    if latest_credit_score.nil?
      'not_calculated'
    elsif needs_credit_score_refresh?
      'outdated'
    else
      'current'
    end
  end

  def loan_application_summary
    applications = loan_applications.group(:status).count
    {
      total: loan_applications.count,
      pending: applications['pending'] || 0,
      approved: applications['approved'] || 0,
      rejected: applications['rejected'] || 0,
      disbursed: applications['disbursed'] || 0
    }
  end

  def financial_profile_complete?
    bank_connections.active.any? && 
    latest_credit_score.present? && 
    !needs_credit_score_refresh?
  end

  # Method to get recommended loan products
  def recommended_loan_products
    return LoanProduct.none unless latest_credit_score

    LoanProduct.active
               .where('min_credit_score <= ?', latest_credit_score.score)
               .where('min_monthly_income <= ?', estimated_monthly_income)
               .order(:interest_rate_min)
  end

  def risk_profile
    return 'unknown' unless latest_credit_score
    
    case latest_credit_score.score
    when 750..850 then 'low_risk'
    when 650..749 then 'medium_risk' 
    when 550..649 then 'high_risk'
    else 'very_high_risk'
    end
  end

  # Calculate user's debt-to-income ratio
  def debt_to_income_ratio
    monthly_income = estimated_monthly_income
    return 0 if monthly_income.zero?

    # Look for loan/debt payments in transactions
    monthly_debt_payments = transactions.where('amount < 0')
                                      .where('description ILIKE ? OR description ILIKE ? OR description ILIKE ?', 
                                             '%loan%', '%credit%', '%mortgage%')
                                      .where(transaction_date: 3.months.ago..)
                                      .sum('ABS(amount)') / 3

    monthly_debt_payments / monthly_income
  end

  def spending_categories
    return {} unless transactions.any?

    total_spending = transactions.where('amount < 0').sum('ABS(amount)')
    return {} if total_spending.zero?

    categories = transactions.where('amount < 0')
                           .group(:transaction_type)
                           .sum('ABS(amount)')

    categories.transform_values { |amount| (amount / total_spending * 100).round(2) }
  end

  def transaction_summary(period = 3.months)
    start_date = period.ago
    period_transactions = transactions.where(transaction_date: start_date..)

    {
      total_count: period_transactions.count,
      total_inflow: period_transactions.where('amount > 0').sum(:amount),
      total_outflow: period_transactions.where('amount < 0').sum('ABS(amount)'),
      average_balance: account_balances.where(created_at: start_date..).average(:current_balance)&.round(2) || 0,
      transaction_frequency: period_transactions.count / (period / 1.month).round(1)
    }
  end
end