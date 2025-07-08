# app/models/credit_score.rb
class CreditScore < ApplicationRecord
  belongs_to :user
  
  validates :score, presence: true, inclusion: { in: 300..850 }
  validates :risk_level, presence: true
  
  enum risk_level: {
    excellent: 'Excellent',
    good: 'Good', 
    fair: 'Fair',
    poor: 'Poor',
    very_poor: 'Very Poor'
  }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :last_6_months, -> { where('created_at >= ?', 6.months.ago) }
  
  def self.calculate_for_user(user)
    analysis_service = CreditAnalysisService.new(user)
    report = analysis_service.generate_credit_report
    
    create!(
      user: user,
      score: report[:overall_score],
      risk_level: report[:risk_level],
      analysis_data: report[:analysis],
      recommendations: report[:recommendations],
      loan_eligibility: report[:loan_eligibility],
      calculated_at: report[:generated_at]
    )
  end
  
  def score_color
    case risk_level
    when 'excellent' then 'text-green-600'
    when 'good' then 'text-blue-600'
    when 'fair' then 'text-yellow-600'
    when 'poor' then 'text-orange-600'
    when 'very_poor' then 'text-red-600'
    else 'text-gray-600'
    end
  end
  
  def score_description
    case score
    when 750..850 then 'Excellent credit. You qualify for the best rates and terms.'
    when 700..749 then 'Good credit. You qualify for favorable rates and terms.'
    when 650..699 then 'Fair credit. You may qualify with higher rates.'
    when 600..649 then 'Poor credit. Limited options with high rates.'
    else 'Very poor credit. Focus on improving your financial habits.'
    end
  end
end

