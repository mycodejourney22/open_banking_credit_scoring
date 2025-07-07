class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.references :bank_connection, null: false, foreign_key: true
      t.string :transaction_id, null: false
      t.string :transaction_type # credit/debit
      t.decimal :amount, precision: 15, scale: 2
      t.string :currency, default: 'NGN'
      t.text :description
      t.string :category
      t.string :merchant_name
      t.json :metadata
      t.datetime :transaction_date
      t.timestamps
    end
    
    add_index :transactions, :transaction_id, unique: true
    add_index :transactions, [:bank_connection_id, :transaction_date]
    add_index :transactions, :category
  end
end