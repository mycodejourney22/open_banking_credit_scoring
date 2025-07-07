# app/jobs/credit_score_calculation_job.rb
class CreditScoreCalculationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    return unless user.financial_profile

    begin
      credit_score = CreditScoringService.new(user).calculate
      
      if credit_score
        # Broadcast update to user's dashboard
        ActionCable.server.broadcast(
          "user_#{user.id}",
          {
            type: 'credit_score_updated',
            score: credit_score.score,
            grade: credit_score.grade,
            updated_at: credit_score.calculated_at
          }
        )
      end
    rescue => e
      Rails.logger.error "Credit score calculation failed for user #{user_id}: #{e.message}"
    end
  end
end