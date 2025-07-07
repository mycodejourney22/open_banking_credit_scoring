class CreateAccountBalances < ActiveRecord::Migration[7.1]
  def change
    create_table :account_balances do |t|
      t.references :bank_connection, null: false, foreign_key: true
      t.decimal :current_balance, precision: 15, scale: 2
      t.decimal :available_balance, precision: 15, scale: 2
      t.decimal :ledger_balance, precision: 15, scale: 2
      t.string :currency, default: 'NGN'
      t.datetime :balance_date
      t.timestamps
    end
    
    add_index :account_balances, [:bank_connection_id, :balance_date]
  end
end