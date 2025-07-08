class LoanProcessingJob < ApplicationJob
  queue_as :loans
  
  def perform(loan_application_id)
    loan_application = LoanApplication.find(loan_application_id)
    
    # Update status to reviewing
    loan_application.update!(status: 'reviewing')
    
    begin
      # Perform automated assessment
      assessment = perform_loan_assessment(loan_application)
      
      # Store assessment data
      loan_application.update!(assessment_data: assessment)
      
      # Make automatic decision based on assessment
      if assessment[:auto_approval_eligible]
        approve_loan(loan_application, assessment)
      elsif assessment[:auto_rejection_eligible]
        reject_loan(loan_application, assessment)
      else
        # Flag for manual review
        loan_application.update!(status: 'reviewing')
        # In a real system, this would notify loan officers
        Rails.logger.info "Loan application #{loan_application.application_number} flagged for manual review"
      end
      
    rescue => e
      Rails.logger.error "Loan processing failed for application #{loan_application.id}: #{e.message}"
      loan_application.update!(status: 'reviewing') # Fallback to manual review
    end
  end
  
  private
  
  def perform_loan_assessment(loan_application)
    user = loan_application.user
    credit_score = loan_application.credit_score
    
    # Basic checks
    assessment = {
      credit_score: credit_score.score,
      risk_level: credit_score.risk_level,
      amount_requested: loan_application.amount_requested,
      debt_to_income_ratio: calculate_debt_to_income(user),
      monthly_income: estimate_monthly_income(user),
      account_stability: assess_account_stability(user),
      transaction_volume: assess_transaction_volume(user),
      overdraft_history: assess_overdraft_history(user)
    }
    
    # Calculate approval likelihood
    assessment[:approval_score] = calculate_approval_score(assessment)
    
    # Determine automatic decisions
    assessment[:auto_approval_eligible] = auto_approval_eligible?(assessment, loan_application)
    assessment[:auto_rejection_eligible] = auto_rejection_eligible?(assessment, loan_application)
    
    # Calculate loan terms if approvable
    if assessment[:approval_score] >= 60
      assessment[:recommended_terms] = calculate_loan_terms(assessment, loan_application)
    end
    
    assessment
  end
  
  def calculate_approval_score(assessment)
    score = 0
    
    # Credit score component (40%)
    case assessment[:credit_score]
    when 750..850 then score += 40
    when 700..749 then score += 35
    when 650..699 then score += 30
    when 600..649 then score += 25
    when 550..599 then score += 20
    else score += 10
    end
    
    # Debt-to-income component (25%)
    case assessment[:debt_to_income_ratio]
    when 0..0.2 then score += 25
    when 0.2..0.3 then score += 20
    when 0.3..0.4 then score += 15
    when 0.4..0.5 then score += 10
    else score += 5
    end
    
    # Income component (20%)
    case assessment[:monthly_income]
    when 300_000..Float::INFINITY then score += 20
    when 200_000..300_000 then score += 18
    when 150_000..200_000 then score += 15
    when 100_000..150_000 then score += 12
    when 50_000..100_000 then score += 8
    else score += 5
    end
    
    # Account stability (10%)
    score += assessment[:account_stability] * 0.1
    
    # Transaction activity (5%)
    score += assessment[:transaction_volume] * 0.05
    
    score.round(2)
  end
  
  def auto_approval_eligible?(assessment, loan_application)
    assessment[:approval_score] >= 85 &&
    assessment[:credit_score] >= 700 &&
    assessment[:debt_to_income_ratio] <= 0.3 &&
    assessment[:monthly_income] >= 100_000 &&
    loan_application.amount_requested <= 500_000 &&
    assessment[:overdraft_history] <= 2
  end
  
  def auto_rejection_eligible?(assessment, loan_application)
    assessment[:approval_score] < 40 ||
    assessment[:credit_score] < 450 ||
    assessment[:debt_to_income_ratio] > 0.6 ||
    assessment[:monthly_income] < 30_000 ||
    assessment[:overdraft_history] > 10
  end
  
  def calculate_loan_terms(assessment, loan_application)
    # Determine interest rate based on credit score and risk
    base_rate = case assessment[:credit_score]
               when 750..850 then 12.0
               when 700..749 then 15.0
               when 650..699 then 18.0
               when 600..649 then 22.0
               else 25.0
               end
    
    # Adjust for debt-to-income ratio
    if assessment[:debt_to_income_ratio] > 0.4
      base_rate += 2.0
    elsif assessment[:debt_to_income_ratio] < 0.2
      base_rate -= 1.0
    end
    
    # Determine maximum loan amount
    income_multiplier = case assessment[:credit_score]
                       when 750..850 then 6
                       when 700..749 then 5
                       when 650..699 then 4
                       else 3
                       end
    
    max_amount_by_income = assessment[:monthly_income] * income_multiplier
    max_amount = [loan_application.amount_requested, max_amount_by_income, 2_000_000].min
    
    # Determine term based on amount and score
    recommended_term = case max_amount
                      when 0..100_000 then 12
                      when 100_000..500_000 then 18
                      when 500_000..1_000_000 then 24
                      else 36
                      end
    
    {
      approved_amount: max_amount,
      interest_rate: base_rate.round(2),
      term_months: recommended_term,
      monthly_payment: calculate_monthly_payment(max_amount, base_rate, recommended_term)
    }
  end
  
  def calculate_monthly_payment(principal, annual_rate, term_months)
    monthly_rate = annual_rate / 100 / 12
    
    if monthly_rate > 0
      payment = principal * (monthly_rate * (1 + monthly_rate) ** term_months) / 
                ((1 + monthly_rate) ** term_months - 1)
    else
      payment = principal / term_months
    end
    
    payment.round(2)
  end
  
  def approve_loan(loan_application, assessment)
    terms = assessment[:recommended_terms]
    
    loan_application.approve!(
      terms[:approved_amount],
      terms[:interest_rate],
      terms[:term_months]
    )
    
    # Send approval notification
    LoanApprovalNotificationJob.perform_later(loan_application.id)
  end
  
  def reject_loan(loan_application, assessment)
    reasons = []
    
    if assessment[:credit_score] < 450
      reasons << "Credit score below minimum requirement"
    end
    
    if assessment[:debt_to_income_ratio] > 0.6
      reasons << "Debt-to-income ratio too high"
    end
    
    if assessment[:monthly_income] < 30_000
      reasons << "Monthly income below minimum requirement"
    end
    
    if assessment[:overdraft_history] > 10
      reasons << "Excessive overdraft history"
    end
    
    loan_application.reject!(reasons.join("; "))
    
    # Send rejection notification
    LoanRejectionNotificationJob.perform_later(loan_application.id)
  end
  
  # Helper methods for assessment
  def calculate_debt_to_income(user)
    # Implementation from CreditAnalysisService
    analysis_service = CreditAnalysisService.new(user)
    analysis_service.send(:calculate_debt_to_income_ratio)
  end
  
  def estimate_monthly_income(user)
    latest_score = user.credit_scores.recent.first
    return 0 unless latest_score&.analysis_data
    
    latest_score.analysis_data.dig('income_analysis', 'average_monthly_income') || 0
  end
  
  def assess_account_stability(user)
    # Score from 0-100 based on account age and consistency
    oldest_connection = user.bank_connections.minimum(:created_at)
    return 0 unless oldest_connection
    
    months_active = ((Time.current - oldest_connection) / 1.month).round
    
    case months_active
    when 0..3 then 20
    when 3..6 then 40
    when 6..12 then 60
    when 12..24 then 80
    else 100
    end
  end
  
  def assess_transaction_volume(user)
    # Score from 0-100 based on transaction frequency
    total_transactions = user.bank_connections.joins(:transactions).count
    
    case total_transactions
    when 0..10 then 20
    when 10..50 then 40
    when 50..100 then 60
    when 100..200 then 80
    else 100
    end
  end
  
  def assess_overdraft_history(user)
    # Count overdraft occurrences in last 6 months
    user.bank_connections
        .joins(:transactions)
        .where(transactions: { transaction_date: 6.months.ago.. })
        .where('transactions.balance_after < 0')
        .count
  end
end
