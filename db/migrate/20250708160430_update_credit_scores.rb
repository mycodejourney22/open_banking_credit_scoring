class UpdateCreditScores < ActiveRecord::Migration[7.1]
  def change
    add_column :credit_scores, :risk_level, :string, null: false
    add_column :credit_scores, :analysis_data, :string
    add_column :credit_scores, :recommendations, :string
    add_column :credit_scores, :loan_eligibility, :string


  end
end
