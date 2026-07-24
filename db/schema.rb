# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_24_000004) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointments", force: :cascade do |t|
    t.datetime "book_datetime"
    t.string "booking_hash"
    t.string "color", default: "#7cbae8"
    t.datetime "created_at", null: false
    t.datetime "end_datetime"
    t.text "id_caldav_calendar"
    t.text "id_google_calendar"
    t.integer "id_services"
    t.integer "id_users_customer"
    t.integer "id_users_provider"
    t.boolean "is_unavailability", default: false
    t.text "location"
    t.text "meeting_link"
    t.text "notes"
    t.datetime "start_datetime"
    t.string "status", default: ""
    t.datetime "updated_at", null: false
    t.index ["booking_hash"], name: "index_appointments_on_booking_hash", unique: true
    t.index ["end_datetime"], name: "index_appointments_on_end_datetime"
    t.index ["id_services"], name: "index_appointments_on_id_services"
    t.index ["id_users_customer"], name: "index_appointments_on_id_users_customer"
    t.index ["id_users_provider", "start_datetime"], name: "index_appointments_on_id_users_provider_and_start_datetime"
    t.index ["start_datetime"], name: "index_appointments_on_start_datetime"
  end

  create_table "blocked_periods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "end_datetime"
    t.string "name"
    t.text "notes"
    t.datetime "start_datetime"
    t.datetime "updated_at", null: false
  end

  create_table "consents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "id_users"
    t.string "ip"
    t.string "name"
    t.string "type"
    t.datetime "updated_at", null: false
  end

  create_table "roles", force: :cascade do |t|
    t.integer "appointments"
    t.integer "blocked_periods"
    t.datetime "created_at", null: false
    t.integer "customers"
    t.boolean "is_admin", default: false
    t.string "name"
    t.integer "services"
    t.string "slug"
    t.integer "system_settings"
    t.datetime "updated_at", null: false
    t.integer "user_settings"
    t.integer "users"
    t.integer "webhooks"
    t.index ["slug"], name: "index_roles_on_slug", unique: true
  end

  create_table "secretaries_providers", id: false, force: :cascade do |t|
    t.integer "id_users_provider", null: false
    t.integer "id_users_secretary", null: false
    t.index ["id_users_secretary", "id_users_provider"], name: "idx_on_id_users_secretary_id_users_provider_111254eeaa", unique: true
  end

  create_table "service_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "services", force: :cascade do |t|
    t.integer "attendants_number", default: 1
    t.string "color", default: "#7cbae8"
    t.datetime "created_at", null: false
    t.string "currency"
    t.text "description"
    t.integer "duration"
    t.integer "id_service_categories"
    t.boolean "is_private", default: false
    t.text "location"
    t.string "name"
    t.decimal "price", precision: 10, scale: 2
    t.integer "slot_interval", default: 15
    t.datetime "updated_at", null: false
    t.index ["id_service_categories"], name: "index_services_on_id_service_categories"
  end

  create_table "services_providers", id: false, force: :cascade do |t|
    t.integer "id_services", null: false
    t.integer "id_users", null: false
    t.index ["id_users", "id_services"], name: "index_services_providers_on_id_users_and_id_services", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["name"], name: "index_settings_on_name", unique: true
  end

  create_table "user_settings", primary_key: "id_users", force: :cascade do |t|
    t.string "caldav_calendar"
    t.string "caldav_password"
    t.boolean "caldav_sync", default: false
    t.string "caldav_url"
    t.string "caldav_username"
    t.string "calendar_view", default: "default"
    t.datetime "created_at", null: false
    t.string "google_calendar"
    t.boolean "google_sync", default: false
    t.text "google_token"
    t.boolean "notifications", default: true
    t.string "password"
    t.datetime "password_reset_expires"
    t.string "password_reset_token"
    t.boolean "require_password_change", default: false, null: false
    t.string "salt"
    t.integer "sync_future_days", default: 90
    t.integer "sync_past_days", default: 30
    t.datetime "updated_at", null: false
    t.string "username"
    t.text "working_plan"
    t.index ["username"], name: "index_user_settings_on_username", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "address"
    t.string "city"
    t.datetime "created_at", null: false
    t.text "custom_field_1"
    t.text "custom_field_2"
    t.text "custom_field_3"
    t.text "custom_field_4"
    t.text "custom_field_5"
    t.string "email"
    t.integer "id_roles", null: false
    t.boolean "is_private", default: false
    t.string "language", default: "english"
    t.text "ldap_dn"
    t.string "mobile_number"
    t.string "name"
    t.text "notes"
    t.string "phone_number"
    t.string "state"
    t.string "timezone", default: "UTC"
    t.datetime "updated_at", null: false
    t.string "zip_code"
    t.index ["email"], name: "index_users_on_email"
    t.index ["id_roles"], name: "index_users_on_id_roles"
  end

  create_table "webhooks", force: :cascade do |t|
    t.text "actions"
    t.datetime "created_at", null: false
    t.boolean "is_ssl_verified", default: true
    t.string "name"
    t.text "notes"
    t.string "secret_header", default: "X-Ea-Token"
    t.string "secret_token"
    t.datetime "updated_at", null: false
    t.text "url"
  end

  create_table "working_plan_exceptions", force: :cascade do |t|
    t.text "breaks"
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.string "end_time"
    t.integer "id_users_provider", null: false
    t.date "start_date", null: false
    t.string "start_time"
    t.datetime "updated_at", null: false
    t.index ["end_date"], name: "index_working_plan_exceptions_on_end_date"
    t.index ["id_users_provider"], name: "index_working_plan_exceptions_on_id_users_provider"
    t.index ["start_date"], name: "index_working_plan_exceptions_on_start_date"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "services", column: "id_services", on_delete: :cascade
  add_foreign_key "appointments", "users", column: "id_users_customer", on_delete: :cascade
  add_foreign_key "appointments", "users", column: "id_users_provider", on_delete: :cascade
  add_foreign_key "secretaries_providers", "users", column: "id_users_provider", on_delete: :cascade
  add_foreign_key "secretaries_providers", "users", column: "id_users_secretary", on_delete: :cascade
  add_foreign_key "services", "service_categories", column: "id_service_categories", on_delete: :nullify
  add_foreign_key "services_providers", "services", column: "id_services", on_delete: :cascade
  add_foreign_key "services_providers", "users", column: "id_users", on_delete: :cascade
  add_foreign_key "user_settings", "users", column: "id_users", on_delete: :cascade
  add_foreign_key "users", "roles", column: "id_roles", on_delete: :cascade
  add_foreign_key "working_plan_exceptions", "users", column: "id_users_provider", on_delete: :cascade
end
