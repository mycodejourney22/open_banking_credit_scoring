class UpdateBankConnectionsForOpenBanking < ActiveRecord::Migration[7.0]
  def change
    # Add new columns for Open Banking OAuth flow
    add_column :bank_connections, :connection_id, :string
    add_column :bank_connections, :device_code, :string
    add_column :bank_connections, :user_code, :string
    add_column :bank_connections, :verification_uri, :string
    add_column :bank_connections, :consent_expires_at, :datetime
    add_column :bank_connections, :polling_interval, :integer, default: 5
    add_column :bank_connections, :consent_token, :text
    add_column :bank_connections, :scopes, :json
    add_column :bank_connections, :error_message, :text
    
    # Update existing columns
    change_column :bank_connections, :status, :string, default: 'pending'
    
    # Add indexes
    add_index :bank_connections, [:user_id, :connection_id], unique: true
    add_index :bank_connections, :device_code
    add_index :bank_connections, :status
    add_index :bank_connections, :token_expires_at
  end
end