class CreateLoanProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :loan_products do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :min_amount, precision: 15, scale: 2, null: false
      t.decimal :max_amount, precision: 15, scale: 2, null: false
      t.integer :min_term_months, null: false
      t.integer :max_term_months, null: false
      t.decimal :interest_rate_min, precision: 5, scale: 2, null: false
      t.decimal :interest_rate_max, precision: 5, scale: 2, null: false
      t.integer :min_credit_score, null: false
      t.decimal :min_monthly_income, precision: 15, scale: 2
      t.json :requirements
      t.json :features
      t.boolean :active, default: true
      t.timestamps
    end
    
    add_index :loan_products, :active
    add_index :loan_products, :min_credit_score
  end
end