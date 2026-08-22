class CreateAppointmentSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_series do |t|
      t.integer :id_users_provider, null: false
      t.integer :id_users_customer, null: false
      t.integer :id_services, null: false
      t.text :schedule, null: false       # IceCube::Schedule#to_hash as JSON
      t.date :starts_on, null: false
      t.date :ends_on                     # nil: open ended, extended nightly to the booking limit
      t.string :start_time, null: false   # HH:MM, provider wall clock
      t.integer :duration, null: false    # minutes
      t.text :notes
      t.text :location
      t.string :status, default: ""
      t.string :color
      t.text :skipped, default: "[]"      # [{date, reason}] dates that clashed and were not booked
      t.text :removed, default: "[]"      # dates the user deleted, never recreated
      t.integer :created_by
      t.timestamps
    end
    add_index :appointment_series, :id_users_provider
    add_index :appointment_series, :id_users_customer

    add_column :appointments, :series_id, :integer
    add_column :appointments, :occurrence_at, :date
    add_index :appointments, :series_id
  end
end
