class CreditScore < ApplicationRecord
  belongs_to :user
  has_many :credit_applications

  validates :score, presence: true, inclusion: { in: 300..850 }
  validates :grade, presence: true, inclusion: { in: %w[A+ A B+ B C+ C D E] }

  before_save :set_grade_from_score

  scope :recent, -> { order(calculated_at: :desc) }

  def self.calculate_for_user(user)
    CreditScoringService.new(user).calculate
  end

  def excellent?
    score >= 750
  end

  def good?
    score >= 650
  end

  def fair?
    score >= 550
  end

  def poor?
    score < 550
  end

  def risk_level
    case score
    when 750..850 then 'Low Risk'
    when 650..749 then 'Medium-Low Risk'
    when 550..649 then 'Medium Risk'
    when 450..549 then 'Medium-High Risk'
    else 'High Risk'
    end
  end

  private

  def set_grade_from_score
    self.grade = case score
                 when 800..850 then 'A+'
                 when 750..799 then 'A'
                 when 700..749 then 'B+'
                 when 650..699 then 'B'
                 when 600..649 then 'C+'
                 when 550..599 then 'C'
                 when 500..549 then 'D'
                 else 'E'
                 end
  end
end