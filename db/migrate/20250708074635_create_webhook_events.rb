class CreateWebhookEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :webhook_events do |t|
      t.string :event_type, null: false
      t.string :event_id, null: false
      t.string :source, null: false
      t.json :payload, null: false
      t.string :status, default: 'pending'
      t.datetime :processed_at
      t.text :error_message
      t.timestamps
    end
    
    add_index :webhook_events, [:event_type, :event_id], unique: true
    add_index :webhook_events, :status
    add_index :webhook_events, :created_at
  end
end