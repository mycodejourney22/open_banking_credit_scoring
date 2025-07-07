class Transaction < ApplicationRecord
  belongs_to :bank_connection

  validates :transaction_id, :transaction_type, :amount, :transaction_date, presence: true
  validates :transaction_id, uniqueness: true
  validates :transaction_type, inclusion: { in: %w[credit debit] }

  scope :credits, -> { where(transaction_type: 'credit') }
  scope :debits, -> { where(transaction_type: 'debit') }
  scope :recent, -> { order(transaction_date: :desc) }
  scope :for_period, ->(start_date, end_date) { where(transaction_date: start_date..end_date) }

  def credit?
    transaction_type == 'credit'
  end

  def debit?
    transaction_type == 'debit'
  end
end