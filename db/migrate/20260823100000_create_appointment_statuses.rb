# Statuses move from the appointment_status_options JSON setting to a table with
# a kind, so the special ones can be renamed. appointments.status (name) becomes
# status_id. Adds Late Cancel, rescheduled_to_id and the late cancellation window.
class CreateAppointmentStatuses < ActiveRecord::Migration[8.1]
  KINDS = { "Booked" => 1, "Rescheduled" => 2, "Cancelled" => 3, "Late Cancel" => 4, "No Show" => 5 }.freeze

  def up
    create_table :appointment_statuses do |t|
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index :name, unique: true
    end
    add_column :appointments, :status_id, :integer
    add_index :appointments, :status_id
    add_column :appointments, :rescheduled_to_id, :integer

    names = JSON.parse(select_value("SELECT value FROM settings WHERE name = 'appointment_status_options'") || "[]")
    names += select_values("SELECT DISTINCT status FROM appointments WHERE status <> '' AND status IS NOT NULL")
    names = (names.map(&:to_s).map(&:strip).reject(&:empty?) | KINDS.keys).uniq
    names.each_with_index do |name, position|
      execute(sanitize("INSERT INTO appointment_statuses (name, kind, position, created_at, updated_at) " \
                       "VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", name, KINDS[name] || 0, position))
    end
    execute("UPDATE appointments SET status_id = (SELECT id FROM appointment_statuses WHERE name = appointments.status) " \
            "WHERE status <> '' AND status IS NOT NULL")
    remove_column :appointments, :status
    execute("DELETE FROM settings WHERE name = 'appointment_status_options'")

    timeout = select_value("SELECT value FROM settings WHERE name = 'book_advance_timeout'") || "30"
    execute(sanitize("INSERT INTO settings (name, value, created_at, updated_at) SELECT ?, ?, CURRENT_TIMESTAMP, " \
                     "CURRENT_TIMESTAMP WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = ?)",
                     "late_cancellation_timeout", timeout, "late_cancellation_timeout"))
  end

  def down
    add_column :appointments, :status, :string, default: ""
    execute("UPDATE appointments SET status = COALESCE((SELECT name FROM appointment_statuses " \
            "WHERE id = appointments.status_id), '')")
    names = select_values("SELECT name FROM appointment_statuses ORDER BY position, id")
    execute(sanitize("INSERT INTO settings (name, value, created_at, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP, " \
                     "CURRENT_TIMESTAMP)", "appointment_status_options", JSON.generate(names)))
    remove_column :appointments, :rescheduled_to_id
    remove_column :appointments, :status_id
    drop_table :appointment_statuses
  end

  private

  def sanitize(sql, *binds)
    ActiveRecord::Base.sanitize_sql_array([ sql ] + binds)
  end
end
