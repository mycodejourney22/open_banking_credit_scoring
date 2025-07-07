class DeviseCreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :first_name
      t.string :last_name
      t.string :phone_number
      t.string :bvn
      t.string :nin
      t.date :date_of_birth
      t.string :employment_status
      t.decimal :declared_income, precision: 15, scale: 2
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :bvn,                  unique: true
    add_index :users, :reset_password_token, unique: true
  end
end