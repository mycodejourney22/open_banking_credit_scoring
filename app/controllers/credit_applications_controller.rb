 # app/controllers/credit_applications_controller.rb
 class CreditApplicationsController < ApplicationController
    before_action :set_credit_application, only: [:show, :edit, :update, :destroy]
    before_action :check_credit_score, only: [:new, :create]
  
    def index
      @credit_applications = current_user.credit_applications.order(created_at: :desc)
    end
  
    def show
    end

    def edit
    end

    def update
    end

    def destroy
    end
    
    def new
      @credit_application = current_user.credit_applications.build
      @latest_credit_score = current_user.latest_credit_score
      @max_loan_amount = calculate_max_loan_amount
    end
  
    def create
      @credit_application = current_user.credit_applications.build(credit_application_params)
      @credit_application.credit_score = current_user.latest_credit_score
      
      # Calculate proposed interest rate based on credit score
      @credit_application.proposed_interest_rate = calculate_interest_rate(@credit_application.credit_score.score)
      
      if @credit_application.save
        # Process application
        process_application(@credit_application)
        redirect_to @credit_application, notice: 'Credit application submitted successfully!'
      else
        @latest_credit_score = current_user.latest_credit_score
        @max_loan_amount = calculate_max_loan_amount
        render :new, status: :unprocessable_entity
      end
    end
  
    private
  
    def set_credit_application
      @credit_application = current_user.credit_applications.find(params[:id])
    end
  
    def credit_application_params
      params.require(:credit_application).permit(:requested_amount, :loan_purpose, :loan_term_months)
    end
  
    def check_credit_score
      unless current_user.latest_credit_score
        redirect_to credit_scores_path, alert: 'Please calculate your credit score first.'
      end
    end
  
    def calculate_max_loan_amount
      return 0 unless current_user.financial_profile&.average_monthly_income
  
      # Conservative estimate: 5x monthly income for high scores, 2x for low scores
      score = current_user.latest_credit_score.score
      multiplier = case score
                   when 750..850 then 5.0
                   when 650..749 then 4.0
                   when 550..649 then 3.0
                   when 450..549 then 2.0
                   else 1.0
                   end
      
      (current_user.financial_profile.average_monthly_income * multiplier).round
    end
  
    def calculate_interest_rate(credit_score)
      # Interest rate based on credit score (annual percentage)
      case credit_score
      when 750..850 then 0.08  # 8%
      when 700..749 then 0.12  # 12%
      when 650..699 then 0.15  # 15%
      when 600..649 then 0.18  # 18%
      when 550..599 then 0.22  # 22%
      when 500..549 then 0.25  # 25%
      else 0.30                # 30%
      end
    end
  
    def process_application(application)
      # Auto-approve based on credit score and requested amount
      score = application.credit_score.score
      requested_amount = application.requested_amount
      max_amount = calculate_max_loan_amount
      
      if score >= 650 && requested_amount <= max_amount
        application.update!(
          status: 'approved',
          approved_at: Time.current,
          expires_at: 30.days.from_now
        )
      elsif score < 500 || requested_amount > max_amount * 1.5
        application.update!(
          status: 'rejected',
          rejection_reason: 'Credit score or requested amount does not meet requirements'
        )
      else
        # Keep as pending for manual review
        application.update!(status: 'pending')
      end
    end
  end