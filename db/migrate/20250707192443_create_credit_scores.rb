class CreateCreditScores < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_scores do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :score, null: false  # 300-850 range
      t.string :grade  # A+, A, B+, B, C+, C, D, E
      t.decimal :default_probability, precision: 5, scale: 4
      t.json :score_breakdown
      t.json :risk_factors
      t.json :improvement_suggestions
      t.string :model_version
      t.datetime :calculated_at
      t.timestamps
    end
    
    add_index :credit_scores, [:user_id, :calculated_at]
    add_index :credit_scores, :score
  end
end
