require "test_helper"

class ImportPageTest < ActionDispatch::IntegrationTest
  setup do
    TenToEightImportJob.status_store = ActiveSupport::Cache::MemoryStore.new
    BackupExportJob.status_store = ActiveSupport::Cache::MemoryStore.new
    BackupExport.dir_override = Rails.root.join("tmp", "backups-test-#{SecureRandom.hex(4)}")
  end

  teardown do
    TenToEightImportJob.status_store = nil
    BackupExportJob.status_store = nil
    FileUtils.rm_rf(BackupExport.dir_override)
    BackupExport.dir_override = nil
  end

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def upload = fixture_file_upload("ten_to_eight_export.csv", "text/csv")

  test "page requires the system settings privilege" do
    get "/import"
    assert_response :redirect

    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    get "/import"
    assert_response :forbidden
  end

  test "analyze returns a dry-run summary" do
    login_admin
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/import/analyze", params: { file: upload, days_back: 21, days_forward: 21 }
    end
    assert_response :success
    body = response.parsed_body
    assert_equal 3, body["summary"]["customers"]
    assert_equal 3, body["summary"]["services"]
    assert_equal 2, body["summary"]["staff"]
    assert_equal 3, body["summary"]["appointments"]
  end

  test "start enqueues the import job and status reports it" do
    login_admin
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_enqueued_with(job: TenToEightImportJob) do
        post "/import/start", params: { file: upload, phases: %w[categories services],
                                        days_back: 21, days_forward: 21 }
      end
    end
    assert_response :success
    import_id = response.parsed_body["import_id"]
    assert import_id.present?

    perform_enqueued_jobs
    get "/import/status", params: { import_id: import_id }
    status = response.parsed_body
    assert_equal "completed", status["state"]
    assert_equal 3, status["counts"]["services"]["created"]
    assert Service.exists?(name: "TS Short trim")
  end

  test "reset requires the exact confirmation text" do
    login_admin
    post "/import/reset", params: { confirmation: "RESET" }
    assert_response :internal_server_error
    assert Appointment.any?

    post "/import/reset", params: { confirmation: "I KNOW WHAT I AM DOING" }
    assert_response :success
    assert_equal 0, Appointment.count
    assert User.admins.any?
    assert Setting.get("company_name").present?
  end

  test "full reset deletes admins, reseeds and recreates the install admin" do
    login_admin
    Setting.set("company_name", "Custom Co")
    old_admin_id = users(:admin).id
    post "/import/reset", params: { confirmation: "I KNOW WHAT I AM DOING", full: "1" }
    assert_response :success
    assert_equal true, response.parsed_body["full"]
    assert_not User.exists?(id: old_admin_id)
    assert_equal 1, User.admins.count
    admin = User.admins.first
    assert admin.settings.require_password_change
    assert_equal "administrator", admin.settings.username
    assert_not_equal "Custom Co", Setting.get("company_name")

    get "/calendar"
    assert_redirected_to "/login"
  end

  test "a stale session for a deleted user is treated as logged out" do
    login_admin
    users(:admin).destroy!
    get "/calendar"
    assert_redirected_to "/login"

    post "/account/save", params: { account: { name: "Ghost" } }, as: :json
    assert_response :unauthorized
  end

  test "a failed reset returns a json message for the banner" do
    login_admin
    singleton = ResetDatabase.singleton_class
    singleton.alias_method :original_run, :run
    singleton.define_method(:run) { |**| raise "boom" }
    begin
      post "/import/reset", params: { confirmation: "I KNOW WHAT I AM DOING", full: "1" }
    ensure
      singleton.alias_method :run, :original_run
      singleton.remove_method :original_run
    end
    assert_response :internal_server_error
    assert_equal "boom", response.parsed_body["message"]

    get "/calendar"
    assert_redirected_to "/login"
  end

  test "export runs in the background and the backups download with all the sheets" do
    login_admin
    post "/import/export"
    assert_response :success
    export_id = response.parsed_body["export_id"]
    assert export_id.present?

    perform_enqueued_jobs
    get "/import/export_status", params: { export_id: export_id }
    assert_equal "completed", response.parsed_body["state"]

    get "/import/backups"
    backups = response.parsed_body["backups"]
    assert_equal 1, backups.size
    assert_match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/, backups.first["date"])
    ods_name = backups.first["files"]["ods"]["name"]
    assert backups.first["files"]["zip"]["name"].end_with?(".zip")
    assert backups.first["files"]["ods"]["size"].present?

    get "/import/download_backup", params: { name: ods_name }
    assert_response :success
    assert_equal Ods::MIMETYPE, response.media_type

    path = Rails.root.join("tmp", "export-test-#{SecureRandom.hex(4)}.ods")
    File.binwrite(path, response.body)
    sheets = Ods.parse(path.to_s)
    assert_equal [ "Service Categories", "Services", "Providers", "Assistants", "Admins",
                   "Customers", "Appointments", "Blocked Periods", "Settings" ], sheets.keys
    customer_rows = sheets["Customers"]
    assert_includes customer_rows.first, "email"
    assert(customer_rows.drop(1).any? { |row| row.include?(users(:jx).email) })
  ensure
    FileUtils.rm_f(path) if path
  end

  test "backup downloads are admin only and validate the name" do
    login_admin
    perform_enqueued_jobs { post "/import/export" }
    ods_name = BackupExport.list.first[:files]["ods"]

    get "/import/download_backup", params: { name: "../../config/master.key" }
    assert_response :internal_server_error

    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    get "/import/download_backup", params: { name: ods_name }
    assert_response :forbidden
    get "/import/backups"
    assert_response :forbidden
    post "/import/export"
    assert_response :forbidden
  end

  test "an exported ODS analyzes and imports back after a reset" do
    login_admin
    provider_email = users(:zane).email
    customer_email = users(:jx).email
    service_name = services(:haircut).name
    upload_path = Rails.root.join("tmp", "roundtrip-#{SecureRandom.hex(4)}.ods")
    File.binwrite(upload_path, DataExport.generate)
    ResetDatabase.run

    ods_upload = Rack::Test::UploadedFile.new(upload_path, Ods::MIMETYPE)
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/import/analyze", params: { file: ods_upload, import_type: "ods",
                                        days_back: 365, days_forward: 365 }
    end
    assert_response :success
    summary = response.parsed_body["summary"]
    assert_operator summary["customers"], :>=, 1
    assert_operator summary["appointments"], :>=, 1

    ods_upload = Rack::Test::UploadedFile.new(upload_path, Ods::MIMETYPE)
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/import/start", params: { file: ods_upload, import_type: "ods",
                                      phases: TenToEight::Load::PHASES, create_providers: "1",
                                      days_back: 365, days_forward: 365 }
    end
    assert_response :success
    perform_enqueued_jobs

    assert User.providers.exists?(email: provider_email)
    assert User.customers.exists?(email: customer_email)
    assert Service.exists?(name: service_name)
    assert_equal 1, Appointment.appointments.count
  ensure
    FileUtils.rm_f(upload_path) if upload_path
  end

  test "analyzing a csv as an ODS returns a clean error message" do
    login_admin
    post "/import/analyze", params: { file: upload, import_type: "ods",
                                      days_back: 21, days_forward: 21 }
    assert_response :internal_server_error
    assert_match(/Not an ODS spreadsheet/, response.parsed_body["message"])
  end

  test "the import strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[import_data import_hint analyze start_import create_providers days_back days_forward
         reset_database reset_database_warning reset_confirmation_hint
         manage_data export_data import_type full_reset_label import_providers_caution].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end

  test "the backup strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[backups backups_hint backup_working backup_failed ods_file zip_file].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end

  test "the settings phase tickbox exists and defaults to unticked" do
    login_admin
    get "/import"
    assert_select "#phase-settings"
    assert_select "#phase-settings[checked]", count: 0
    assert_select "#phase-customers[checked]"
  end

  test "settings restore from an exported ODS only when the phase is selected" do
    login_admin
    Setting.set("company_name", "Backup Co")
    Setting.set("umami_analytics_url", "https://stats.example.org")
    upload_path = Rails.root.join("tmp", "settings-roundtrip-#{SecureRandom.hex(4)}.ods")
    File.binwrite(upload_path, DataExport.generate)
    Setting.set("company_name", "Changed Co")
    Setting.set("umami_analytics_url", "")

    # Default phases (settings unticked): settings stay as they are.
    perform_enqueued_jobs do
      post "/import/start", params: {
        file: Rack::Test::UploadedFile.new(upload_path, Ods::MIMETYPE), import_type: "ods",
        phases: [ "customers" ], days_back: 365, days_forward: 365
      }
    end
    assert_equal "Changed Co", Setting.get("company_name")

    # With the settings phase every exported key restores, integrations included.
    post "/import/start", params: {
      file: Rack::Test::UploadedFile.new(upload_path, Ods::MIMETYPE), import_type: "ods",
      phases: [ "settings" ], days_back: 365, days_forward: 365
    }
    import_id = response.parsed_body["import_id"]
    perform_enqueued_jobs
    assert_equal "Backup Co", Setting.get("company_name")
    assert_equal "https://stats.example.org", Setting.get("umami_analytics_url")

    status = TenToEightImportJob.read_status(import_id)
    assert_equal "completed", status[:state]
    assert_operator status[:counts][:settings][:matched], :>, 0
  ensure
    FileUtils.rm_f(upload_path) if upload_path
  end

  test "analyze reports the settings count for an ODS backup" do
    login_admin
    upload_path = Rails.root.join("tmp", "settings-analyze-#{SecureRandom.hex(4)}.ods")
    File.binwrite(upload_path, DataExport.generate)
    post "/import/analyze", params: {
      file: Rack::Test::UploadedFile.new(upload_path, Ods::MIMETYPE), import_type: "ods",
      days_back: 365, days_forward: 365
    }
    assert_response :success
    assert_equal Setting.count, response.parsed_body["summary"]["settings"]
  ensure
    FileUtils.rm_f(upload_path) if upload_path
  end

  test "the optional images zip attaches pictures, a plain ods imports without" do
    require "zip"
    login_admin
    services(:haircut).picture.attach(
      io: StringIO.new(file_fixture("picture.png").binread), filename: "haircut.png", content_type: "image/png"
    )
    ods_path = Rails.root.join("tmp", "images-zip-test-#{SecureRandom.hex(4)}.ods")
    File.binwrite(ods_path, DataExport.generate)
    zip_path = Rails.root.join("tmp", "images-zip-test-#{SecureRandom.hex(4)}.zip")
    Zip::OutputStream.open(zip_path) do |stream|
      stream.put_next_entry("haircut.png")
      stream.write(file_fixture("picture.png").binread)
    end
    services(:haircut).picture.purge

    # Without the zip the data imports and no picture attaches.
    post "/import/start", params: {
      file: Rack::Test::UploadedFile.new(ods_path, Ods::MIMETYPE), import_type: "ods",
      phases: [ "services" ], days_back: 21, days_forward: 21
    }
    perform_enqueued_jobs
    assert_not services(:haircut).reload.picture.attached?

    # With the zip the referenced picture attaches.
    post "/import/start", params: {
      file: Rack::Test::UploadedFile.new(ods_path, Ods::MIMETYPE),
      images_file: Rack::Test::UploadedFile.new(zip_path, "application/zip"),
      import_type: "ods", phases: [ "services" ], days_back: 21, days_forward: 21
    }
    perform_enqueued_jobs
    assert services(:haircut).reload.picture.attached?
  ensure
    FileUtils.rm_f(ods_path) if ods_path
    FileUtils.rm_f(zip_path) if zip_path
  end

  test "the images strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[images_zip_optional images_zip_hint].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
