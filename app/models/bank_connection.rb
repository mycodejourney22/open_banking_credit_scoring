class BankConnection < ApplicationRecord
    belongs_to :user
    has_many :transactions, dependent: :destroy
    has_many :account_balances, dependent: :destroy
  
    encrypts :access_token, :refresh_token
  
    validates :bank_code, :bank_name, :account_number, presence: true
    validates :account_number, uniqueness: { scope: [:user_id, :bank_code] }
  
    scope :active, -> { where(status: 'active') }
  
    def needs_token_refresh?
      token_expires_at && token_expires_at < 1.hour.from_now
    end
  
    def latest_balance
      account_balances.order(balance_date: :desc).first
    end
  
    def sync_data!
      OpenBankingDataSyncJob.perform_async(id)
    end
  end