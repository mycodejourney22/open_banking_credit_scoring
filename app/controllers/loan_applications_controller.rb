
  # app/controllers/loan_applications_controller.rb
  class LoanApplicationsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_loan_application, only: [:show, :update, :destroy]
    before_action :check_credit_score, only: [:new, :create]
    
    def index
      @loan_applications = current_user.loan_applications.recent.includes(:credit_score)
      @active_applications = @loan_applications.active
      @past_applications = @loan_applications.where(status: ['approved', 'rejected', 'disbursed'])
    end
    
    def show
      @monthly_payment = @loan_application.monthly_payment
      @total_repayment = @loan_application.total_repayment
    end
    
    def new
      @loan_application = current_user.loan_applications.build
      @loan_products = LoanProduct.active.for_credit_score(@latest_credit_score.score)
      @max_eligible_amount = calculate_max_eligible_amount
    end
    
    def create
      @loan_application = current_user.loan_applications.build(loan_application_params)
      @loan_application.credit_score = @latest_credit_score
      
      if @loan_application.save
        redirect_to @loan_application, notice: 'Loan application submitted successfully! We will review your application and get back to you soon.'
      else
        @loan_products = LoanProduct.active.for_credit_score(@latest_credit_score.score)
        @max_eligible_amount = calculate_max_eligible_amount
        render :new, status: :unprocessable_entity
      end
    end
    
    def update
      if @loan_application.update(loan_application_params)
        redirect_to @loan_application, notice: 'Loan application updated successfully.'
      else
        render :show, status: :unprocessable_entity
      end
    end
    
    def destroy
      if @loan_application.pending?
        @loan_application.destroy
        redirect_to loan_applications_path, notice: 'Loan application cancelled successfully.'
      else
        redirect_to @loan_application, alert: 'Cannot cancel application at this stage.'
      end
    end
    
    private
    
    def set_loan_application
      @loan_application = current_user.loan_applications.find(params[:id])
    end
    
    def loan_application_params
      params.require(:loan_application).permit(:amount_requested, :purpose, :description)
    end
    
    def check_credit_score
      @latest_credit_score = current_user.credit_scores.recent.first
      
      unless @latest_credit_score
        redirect_to calculate_credit_scores_path, alert: 'Please calculate your credit score first before applying for a loan.'
        return
      end
      
      # Check if credit score is recent (within 30 days)
      if @latest_credit_score.created_at < 30.days.ago
        redirect_to refresh_credit_scores_path, alert: 'Your credit score is outdated. Please refresh it before applying for a loan.'
        return
      end
      
      # Check minimum credit score requirement
      if @latest_credit_score.score < 400
        redirect_to credit_scores_path, alert: 'Your current credit score does not meet the minimum requirements for loan applications. Focus on improving your financial habits and try again later.'
        return
      end
    end
    
    def calculate_max_eligible_amount
      return 0 unless @latest_credit_score&.loan_eligibility
      
      @latest_credit_score.loan_eligibility['max_loan_amount'] || 0
    end
  end
  

    