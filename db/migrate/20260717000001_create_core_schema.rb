# Schema ported from Easy!Appointments 1.6.0 (migrations 001-069, ea_ prefix dropped).
# EA column names (id_roles, id_users_provider, ...) are kept so API serializers and
# ported queries stay mechanical. EA's `hash` column is `booking_hash` here because
# `hash` is a reserved attribute name in ActiveRecord.
# Datetimes are provider-local wall-clock, not UTC. See config/application.rb.
class CreateCoreSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :name
      t.string :slug
      t.boolean :is_admin, default: false
      t.integer :appointments
      t.integer :customers
      t.integer :services
      t.integer :users
      t.integer :system_settings
      t.integer :user_settings
      t.integer :webhooks
      t.integer :blocked_periods
      t.timestamps
    end
    add_index :roles, :slug, unique: true

    create_table :users do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :mobile_number
      t.string :phone_number
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.text :notes
      t.string :timezone, default: "UTC"
      t.string :language, default: "english"
      t.boolean :is_private, default: false
      t.text :ldap_dn
      t.text :custom_field_1
      t.text :custom_field_2
      t.text :custom_field_3
      t.text :custom_field_4
      t.text :custom_field_5
      t.integer :id_roles, null: false
      t.timestamps
    end
    add_index :users, :email
    add_index :users, :id_roles
    add_foreign_key :users, :roles, column: :id_roles, on_delete: :cascade

    create_table :user_settings, id: false do |t|
      t.integer :id_users, primary_key: true
      t.string :username
      t.string :password
      t.string :salt
      t.text :working_plan
      t.boolean :notifications, default: true
      t.string :calendar_view, default: "default"
      t.boolean :google_sync, default: false
      t.text :google_token
      t.string :google_calendar
      t.boolean :caldav_sync, default: false
      t.string :caldav_url
      t.string :caldav_username
      t.string :caldav_password
      t.string :caldav_calendar
      t.integer :sync_past_days, default: 30
      t.integer :sync_future_days, default: 90
      t.string :password_reset_token
      t.datetime :password_reset_expires
      t.timestamps
    end
    add_index :user_settings, :username, unique: true
    add_foreign_key :user_settings, :users, column: :id_users, on_delete: :cascade

    create_table :service_categories do |t|
      t.string :name
      t.text :description
      t.timestamps
    end

    create_table :services do |t|
      t.string :name
      t.integer :duration
      t.decimal :price, precision: 10, scale: 2
      t.string :currency
      t.text :description
      t.text :location
      t.string :color, default: "#7cbae8"
      t.integer :slot_interval, default: 15
      t.integer :attendants_number, default: 1
      t.boolean :is_private, default: false
      t.integer :id_service_categories
      t.timestamps
    end
    add_index :services, :id_service_categories
    add_foreign_key :services, :service_categories, column: :id_service_categories, on_delete: :nullify

    create_table :services_providers, id: false do |t|
      t.integer :id_users, null: false
      t.integer :id_services, null: false
    end
    add_index :services_providers, [ :id_users, :id_services ], unique: true
    add_foreign_key :services_providers, :users, column: :id_users, on_delete: :cascade
    add_foreign_key :services_providers, :services, column: :id_services, on_delete: :cascade

    create_table :secretaries_providers, id: false do |t|
      t.integer :id_users_secretary, null: false
      t.integer :id_users_provider, null: false
    end
    add_index :secretaries_providers, [ :id_users_secretary, :id_users_provider ], unique: true
    add_foreign_key :secretaries_providers, :users, column: :id_users_secretary, on_delete: :cascade
    add_foreign_key :secretaries_providers, :users, column: :id_users_provider, on_delete: :cascade

    create_table :appointments do |t|
      t.datetime :book_datetime
      t.datetime :start_datetime
      t.datetime :end_datetime
      t.text :location
      t.text :meeting_link
      t.text :notes
      t.string :booking_hash
      t.string :color, default: "#7cbae8"
      t.string :status, default: ""
      t.boolean :is_unavailability, default: false
      t.integer :id_users_provider
      t.integer :id_users_customer
      t.integer :id_services
      t.text :id_google_calendar
      t.text :id_caldav_calendar
      t.timestamps
    end
    add_index :appointments, :booking_hash, unique: true
    add_index :appointments, [ :id_users_provider, :start_datetime ]
    add_index :appointments, :id_users_customer
    add_index :appointments, :id_services
    add_index :appointments, :start_datetime
    add_index :appointments, :end_datetime
    add_foreign_key :appointments, :users, column: :id_users_provider, on_delete: :cascade
    add_foreign_key :appointments, :users, column: :id_users_customer, on_delete: :cascade
    add_foreign_key :appointments, :services, column: :id_services, on_delete: :cascade

    create_table :settings do |t|
      t.string :name
      t.text :value
      t.timestamps
    end
    add_index :settings, :name, unique: true

    create_table :webhooks do |t|
      t.string :name
      t.text :url
      t.text :actions
      t.string :secret_token
      t.string :secret_header, default: "X-Ea-Token"
      t.boolean :is_ssl_verified, default: true
      t.text :notes
      t.timestamps
    end

    create_table :blocked_periods do |t|
      t.string :name
      t.datetime :start_datetime
      t.datetime :end_datetime
      t.text :notes
      t.timestamps
    end

    # start_time/end_time are HH:MM strings (wall-clock), matching EA's TIME columns.
    create_table :working_plan_exceptions do |t|
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :start_time
      t.string :end_time
      t.text :breaks
      t.integer :id_users_provider, null: false
      t.timestamps
    end
    add_index :working_plan_exceptions, :start_date
    add_index :working_plan_exceptions, :end_date
    add_index :working_plan_exceptions, :id_users_provider
    add_foreign_key :working_plan_exceptions, :users, column: :id_users_provider, on_delete: :cascade

    create_table :consents do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :ip
      t.string :type
      t.integer :id_users
      t.timestamps
    end
  end
end
