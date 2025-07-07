class CreditApplication < ApplicationRecord
  belongs_to :user
  belongs_to :credit_score
end
