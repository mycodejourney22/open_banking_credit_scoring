class LoanRejectionNotificationJob < ApplicationJob
  queue_as :notifications
  
  def perform(loan_application_id)
    loan_application = LoanApplication.find(loan_application_id)
    
    # Send email notification
    LoanMailer.rejection_notification(loan_application).deliver_now
  end
end