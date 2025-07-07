# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
    before_action :authenticate_user!
    before_action :configure_permitted_parameters, if: :devise_controller?
    
    protect_from_forgery with: :exception
    
    rescue_from OpenBankingError, with: :handle_open_banking_error
  
    private
  
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [
        :first_name, :last_name, :phone_number, :bvn, :nin, 
        :date_of_birth, :employment_status, :declared_income
      ])
      devise_parameter_sanitizer.permit(:account_update, keys: [
        :first_name, :last_name, :phone_number, :employment_status, :declared_income
      ])
    end
  
    def handle_open_banking_error(exception)
      flash[:alert] = "Banking service error: #{exception.message}"
      redirect_back(fallback_location: root_path)
    end
end