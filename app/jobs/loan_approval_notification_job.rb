class LoanApprovalNotificationJob < ApplicationJob
  queue_as :notifications
  
  def perform(loan_application_id)
    loan_application = LoanApplication.find(loan_application_id)
    
    # Send email notification
    LoanMailer.approval_notification(loan_application).deliver_now
    
    # Could also send SMS notification
    # SmsService.send_approval_notification(loan_application.user.phone, loan_application)
  end
end