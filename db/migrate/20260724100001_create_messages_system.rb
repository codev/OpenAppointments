class CreateMessagesSystem < ActiveRecord::Migration[8.1]
  def change
    # Notification templates managed on the Messages > Notifications page.
    create_table :notifications do |t|
      t.string :title, null: false
      t.string :description
      t.string :event, null: false
      t.string :lead_mode, default: "before" # coming_up only: before | day_at
      t.integer :lead_days, default: 0
      t.integer :lead_hours, default: 1
      t.string :send_time, default: "08:00" # day_at mode
      t.text :audiences, default: '["customer"]'
      t.text :channels, default: "[]"
      t.string :short_text
      t.text :long_text
      t.timestamps
    end

    # Every outgoing and incoming message; doubles as the log and the per-customer
    # conversation. customer_id nil marks an unknown-sender inbound message.
    create_table :messages do |t|
      t.string :direction, null: false # outgoing | incoming
      t.string :channel, null: false # email | twilio | plivo | textanywhere
      t.string :audience # outgoing: customer | provider | admins
      t.string :to_address
      t.string :from_address
      t.integer :customer_id
      t.integer :sent_by_id
      t.integer :appointment_id
      t.integer :notification_id
      t.string :subject
      t.text :body
      t.string :status, default: "queued" # queued | sent | failed
      t.string :error
      t.datetime :read_at
      t.timestamps
    end
    add_index :messages, :customer_id
    add_index :messages, :created_at
    add_index :messages, [ :direction, :read_at ]

    # Dedupe for coming_up sends; key includes the appointment start so a
    # reschedule sends again.
    create_table :notification_dispatches do |t|
      t.integer :notification_id, null: false
      t.integer :appointment_id, null: false
      t.string :dedupe_key, null: false
      t.timestamps
    end
    add_index :notification_dispatches, :dedupe_key, unique: true

    # Action Mailbox (incoming email ingestion).
    create_table :action_mailbox_inbound_emails do |t|
      t.integer :status, default: 0, null: false
      t.string :message_id, null: false
      t.string :message_checksum, null: false
      t.timestamps
      t.index [ :message_id, :message_checksum ], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
    end
  end
end
