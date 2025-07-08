# app/models/loan_application.rb
class LoanApplication < ApplicationRecord
  belongs_to :user
  belongs_to :credit_score, optional: true
  
  validates :amount_requested, presence: true, numericality: { greater_than: 0 }
  validates :purpose, presence: true
  validates :status, inclusion: { in: %w[pending reviewing approved rejected disbursed] }
  
  enum status: {
    pending: 'pending',
    reviewing: 'reviewing', 
    approved: 'approved',
    rejected: 'rejected',
    disbursed: 'disbursed'
  }
  
  enum purpose: {
    business: 'business',
    personal: 'personal',
    education: 'education',
    medical: 'medical',
    home_improvement: 'home_improvement',
    debt_consolidation: 'debt_consolidation',
    other: 'other'
  }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: ['pending', 'reviewing', 'approved']) }
  
  before_create :set_application_number
  after_create :initiate_credit_check
  
  def monthly_payment
    return 0 unless approved? && interest_rate && term_months
    
    monthly_rate = interest_rate / 100 / 12
    principal = amount_requested
    
    if monthly_rate > 0
      payment = principal * (monthly_rate * (1 + monthly_rate) ** term_months) / 
                ((1 + monthly_rate) ** term_months - 1)
    else
      payment = principal / term_months
    end
    
    payment.round(2)
  end
  
  def total_repayment
    monthly_payment * (term_months || 0)
  end
  
  def total_interest
    total_repayment - amount_requested
  end
  
  def approve!(amount, rate, term)
    update!(
      status: 'approved',
      amount_approved: amount,
      interest_rate: rate,
      term_months: term,
      approved_at: Time.current
    )
  end
  
  def reject!(reason)
    update!(
      status: 'rejected',
      rejection_reason: reason,
      reviewed_at: Time.current
    )
  end
  
  private
  
  def set_application_number
    self.application_number = "LA#{Date.current.strftime('%Y%m')}#{SecureRandom.hex(4).upcase}"
  end
  
  def initiate_credit_check
    LoanProcessingJob.perform_later(self.id)
  end
end