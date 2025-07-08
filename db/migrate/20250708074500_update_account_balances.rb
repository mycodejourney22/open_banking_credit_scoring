class UpdateAccountBalances < ActiveRecord::Migration[7.1]
  def change
    add_column :account_balances, :account_number, :string, null: false
  end
end
