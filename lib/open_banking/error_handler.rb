module OpenBanking
    class ErrorHandler
      def self.handle_api_error(error, context = {})
        case error
        when OpenBankingApiService::OpenBankingError
          log_api_error(error, context)
          
          # Send notification for critical errors
          if critical_error?(error)
            OpenBankingErrorNotificationJob.perform_later(error, context)
          end
          
          # Return appropriate response
          {
            error: true,
            message: user_friendly_message(error),
            code: error.error_code,
            retry_after: retry_delay(error)
          }
        else
          log_unexpected_error(error, context)
          {
            error: true,
            message: "An unexpected error occurred. Please try again later.",
            code: "UNEXPECTED_ERROR"
          }
        end
      end
      
      private
      
      def self.log_api_error(error, context)
        Rails.logger.error do
          {
            message: "Open Banking API Error",
            error_class: error.class.name,
            error_message: error.message,
            status_code: error.status_code,
            error_code: error.error_code,
            context: context
          }.to_json
        end
      end
      
      def self.log_unexpected_error(error, context)
        Rails.logger.error do
          {
            message: "Unexpected Open Banking Error",
            error_class: error.class.name,
            error_message: error.message,
            backtrace: error.backtrace&.first(10),
            context: context
          }.to_json
        end
      end
      
      def self.critical_error?(error)
        return false unless error.is_a?(OpenBankingApiService::OpenBankingError)
        
        # Define critical error conditions
        error.status_code.in?([500, 502, 503, 504]) ||
        error.error_code.in?(['SYSTEM_ERROR', 'SERVICE_UNAVAILABLE'])
      end
      
      def self.user_friendly_message(error)
        case error.status_code
        when 400
          "Invalid request. Please check your input and try again."
        when 401
          "Your banking connection has expired. Please reconnect your account."
        when 403
          "Access denied. You don't have permission to perform this action."
        when 404
          "The requested resource was not found."
        when 429
          "Too many requests. Please wait a moment and try again."
        when 500..599
          "Our banking service is temporarily unavailable. Please try again later."
        else
          error.message || "An error occurred while processing your request."
        end
      end
      
      def self.retry_delay(error)
        case error.status_code
        when 429
          60 # Rate limited - wait 1 minute
        when 500..599
          300 # Server error - wait 5 minutes
        else
          nil
        end
      end
    end
end