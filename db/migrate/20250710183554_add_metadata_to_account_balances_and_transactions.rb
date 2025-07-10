class AddMetadataToAccountBalancesAndTransactions < ActiveRecord::Migration[7.1]
  def change
    # Add metadata column to account_balances only (transactions already has it)
    add_column :account_balances, :metadata, :jsonb
    
    # Skip all indexes for now - we can add them later if needed
  end
end