class CreateBankConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :bank_connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :bank_code, null: false
      t.string :bank_name, null: false
      t.string :account_number, null: false
      t.string :account_name
      t.string :account_type
      t.text :encrypted_access_token
      t.text :encrypted_refresh_token
      t.datetime :token_expires_at
      t.string :consent_id
      t.string :status, default: 'active'
      t.datetime :last_synced_at
      t.timestamps
    end
    
    add_index :bank_connections, [:user_id, :bank_code, :account_number], unique: true
    add_index :bank_connections, :consent_id
  end
end