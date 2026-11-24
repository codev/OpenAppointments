# One row per significant thing the system did, shown on the admin Activity page.
class CreateActivityEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_events do |t|
      t.string :kind, null: false
      t.string :actor, null: false
      t.text :summary, null: false
      t.text :details
      t.integer :appointment_id
      t.integer :customer_id
      t.integer :message_id
      t.integer :user_id
      t.timestamps
    end
    add_index :activity_events, :created_at
    add_index :activity_events, :kind
  end
end
