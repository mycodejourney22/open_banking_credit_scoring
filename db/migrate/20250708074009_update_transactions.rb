class UpdateTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :transactions, :external_transaction_id, :string,  null: false 
    add_column :transactions, :account_number, :string, null: false
    add_column :transactions, :reference, :string
    add_column :transactions, :balance_after, :decimal, precision: 15, scale: 2
    add_column :transactions, :status, :string, default: 'completed'
  end
end
