class CreateFinancialProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :financial_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :average_monthly_income, precision: 15, scale: 2
      t.decimal :average_monthly_expenses, precision: 15, scale: 2
      t.decimal :savings_rate, precision: 5, scale: 4
      t.decimal :debt_to_income_ratio, precision: 5, scale: 4
      t.decimal :expense_volatility, precision: 5, scale: 4
      t.integer :transaction_frequency
      t.json :spending_categories
      t.json :income_sources
      t.datetime :profile_updated_at
      t.timestamps
    end
  end
end