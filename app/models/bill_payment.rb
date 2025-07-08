class BillPayment < ApplicationRecord
  belongs_to :bank_connection
  has_one :user, through: :bank_connection
  
  validates :category_id, presence: true
  validates :biller_id, presence: true
  validates :bill_reference, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :source_account_number, presence: true
  validates :payer_name, presence: true
  validates :status, inclusion: { in: %w[PENDING SUCCESSFUL FAILED REVERSED] }
  
  enum status: {
    pending: 'PENDING',
    successful: 'SUCCESSFUL',
    failed: 'FAILED',
    reversed: 'REVERSED'
  }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: 'SUCCESSFUL') }
  scope :by_biller, ->(biller_id) { where(biller_id: biller_id) }
  
  def total_amount
    amount + (fee || 0)
  end
  
  def success?
    status == 'SUCCESSFUL'
  end
  
  def pending?
    status == 'PENDING'
  end
  
  def failed?
    status == 'FAILED'
  end
end