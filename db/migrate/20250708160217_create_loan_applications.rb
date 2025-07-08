class CreateLoanApplications < ActiveRecord::Migration[7.1]
  def change
    create_table :loan_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :credit_score, null: true, foreign_key: true
      t.string :application_number, null: false
      t.decimal :amount_requested, precision: 15, scale: 2, null: false
      t.decimal :amount_approved, precision: 15, scale: 2
      t.string :purpose, null: false
      t.text :description
      t.string :status, default: 'pending'
      t.decimal :interest_rate, precision: 5, scale: 2
      t.integer :term_months
      t.text :rejection_reason
      t.json :supporting_documents
      t.json :assessment_data
      t.datetime :approved_at
      t.datetime :reviewed_at
      t.datetime :disbursed_at
      t.timestamps
    end
    
    add_index :loan_applications, :application_number, unique: true
    add_index :loan_applications, [:user_id, :status]
    add_index :loan_applications, :status
    add_index :loan_applications, :created_at
  end
end