# app/services/rate_limit_handler.rb
class RateLimitHandler
    RATE_LIMIT_DELAY = {
      default: 1.second,
      too_many_requests: 60.seconds,
      server_error: 5.minutes
    }.freeze
    
    MAX_RETRIES = 3
    
    def self.with_rate_limiting(context: nil, &block)
      retries = 0
      
      begin
        result = yield
        
        # Reset success counter on successful call
        Rails.cache.delete("rate_limit_failures_#{context}")
        
        result
      rescue OpenBankingApiService::OpenBankingError => e
        retries += 1
        failure_count = Rails.cache.read("rate_limit_failures_#{context}") || 0
        
        case e.status_code
        when 429 # Rate Limited
          Rails.logger.warn "Rate limit hit for #{context}, attempt #{retries}/#{MAX_RETRIES}"
          
          if retries <= MAX_RETRIES
            delay = calculate_backoff_delay(failure_count, :too_many_requests)
            Rails.cache.write("rate_limit_failures_#{context}", failure_count + 1, expires_in: 1.hour)
            
            Rails.logger.info "Waiting #{delay} seconds before retry..."
            sleep(delay)
            retry
          else
            raise e
          end
          
        when 500..599 # Server Errors
          Rails.logger.warn "Server error for #{context}, attempt #{retries}/#{MAX_RETRIES}"
          
          if retries <= MAX_RETRIES
            delay = calculate_backoff_delay(retries - 1, :server_error)
            sleep(delay)
            retry
          else
            raise e
          end
          
        else
          raise e
        end
      end
    end
    
    private
    
    def self.calculate_backoff_delay(attempt, error_type)
      base_delay = RATE_LIMIT_DELAY[error_type] || RATE_LIMIT_DELAY[:default]
      
      # Exponential backoff with jitter
      delay = base_delay * (2 ** attempt)
      jitter = rand(0.5..1.5)
      
      (delay * jitter).clamp(1.second, 5.minutes)
    end
end