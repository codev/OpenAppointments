class CreateWaitlistEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :waitlist_entries do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.integer :service_id, null: false
      t.integer :provider_id
      t.integer :duration, null: false
      t.datetime :expires_at, null: false
      t.integer :notices_sent, null: false, default: 0
      t.datetime :last_digest_at
      t.string :unsubscribe_token, null: false
      t.timestamps
    end
    add_index :waitlist_entries, :unsubscribe_token, unique: true
    add_index :waitlist_entries, :expires_at
    add_index :waitlist_entries, :service_id
  end
end
