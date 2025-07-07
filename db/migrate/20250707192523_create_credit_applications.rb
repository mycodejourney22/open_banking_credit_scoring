class CreateCreditApplications < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :credit_score, foreign_key: true
      t.decimal :requested_amount, precision: 15, scale: 2
      t.string :loan_purpose
      t.integer :loan_term_months
      t.decimal :proposed_interest_rate, precision: 5, scale: 4
      t.string :status, default: 'pending'
      t.text :rejection_reason
      t.json :terms_and_conditions
      t.datetime :approved_at
      t.datetime :expires_at
      t.timestamps
    end
    
    add_index :credit_applications, [:user_id, :status]
    add_index :credit_applications, :status
  end
end