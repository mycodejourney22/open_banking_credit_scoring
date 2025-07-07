class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :bank_connections, dependent: :destroy
  has_many :transactions, through: :bank_connections
  has_one :financial_profile, dependent: :destroy
  has_many :credit_scores, dependent: :destroy
  has_many :credit_applications, dependent: :destroy

  validates :first_name, :last_name, presence: true
  validates :phone_number, presence: true, format: { with: /\A\+?234[0-9]{10}\z/ }
  validates :bvn, presence: true, length: { is: 11 }, uniqueness: true
  validates :nin, length: { is: 11 }, allow_blank: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def latest_credit_score
    credit_scores.order(calculated_at: :desc).first
  end

  def has_active_bank_connections?
    bank_connections.where(status: 'active').exists?
  end

  def total_balance
    bank_connections.active.joins(:account_balances)
                   .sum('account_balances.current_balance')
  end
end