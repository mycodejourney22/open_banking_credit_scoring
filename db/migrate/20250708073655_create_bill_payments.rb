class CreateBillPayments < ActiveRecord::Migration[7.1]
  def change
    create_table :bill_payments do |t|
      t.references :bank_connection, null: false, foreign_key: true
      t.string :category_id, null: false
      t.string :biller_id, null: false
      t.string :bill_reference, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.decimal :fee, precision: 15, scale: 2, default: 0
      t.string :source_account_number, null: false
      t.string :payer_name, null: false
      t.string :payer_email
      t.string :payer_phone
      t.string :external_reference
      t.string :status, default: 'PENDING'
      t.string :status_message
      t.json :metadata
      t.datetime :completed_at
      t.timestamps
    end
    
    # Indexes for performance and uniqueness
    add_index :bill_payments, [:bank_connection_id, :external_reference], 
              unique: true, 
              name: 'index_bill_payments_on_connection_and_reference'
    add_index :bill_payments, :status
    add_index :bill_payments, :created_at
    add_index :bill_payments, [:category_id, :biller_id]
    add_index :bill_payments, :bill_reference
    add_index :bill_payments, :source_account_number
  end
end
