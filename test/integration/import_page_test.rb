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

  test "the old import path redirects to the data page" do
    login_admin
    get "/import"
    assert_redirected_to "/data"
  end

  test "page requires the system settings privilege" do
    get "/data"
    assert_response :redirect

    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    get "/data"
    assert_response :forbidden
  end

  # A frame whose src is the page it sits in is refused by Turbo and emptied.
  test "the page frames carry no source of their own and poll through a separate address" do
    login_admin
    get "/data"
    assert_select "turbo-frame#backups:not([src]) #export-data"
    assert_select "turbo-frame#import-status:not([src])"

    BackupExportJob.write_status("abc123", { state: "running" })
    get "/data", params: { export_id: "abc123" }
    assert_select "turbo-frame#backups:not([src])[data-poll-every][data-poll-src='/data?export_id=abc123']"
    TenToEightImportJob.write_status("def456", { state: "running", phase: "services" })
    get "/data", params: { import_id: "def456" }
    assert_select "turbo-frame#import-status:not([src])[data-poll-every][data-poll-src='/data?import_id=def456']"
  end

  test "analyze returns a dry-run summary" do
    login_admin
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/data/analyze", params: { file: upload, days_back: 21, days_forward: 21 }
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
        post "/data/start", params: { file: upload, phases: %w[categories services],
                                        days_back: 21, days_forward: 21 }
      end
    end
    assert_response :success
    import_id = response.parsed_body["import_id"]
    assert import_id.present?

    perform_enqueued_jobs
    get "/data/status", params: { import_id: import_id }
    status = response.parsed_body
    assert_equal "completed", status["state"]
    assert_equal 3, status["counts"]["services"]["created"]
    assert Service.exists?(name: "TS Short trim")
  end

  test "reset requires the exact confirmation text" do
    login_admin
    post "/data/reset", params: { confirmation: "RESET" }
    assert_response :internal_server_error
    assert Appointment.any?

    post "/data/reset", params: { confirmation: "I KNOW WHAT I AM DOING" }
    assert_response :success
    assert_equal 0, Appointment.count
    assert User.admins.any?
    assert Setting.get("company_name").present?
  end

  test "full reset deletes admins, reseeds and recreates the install admin" do
    login_admin
    Setting.set("company_name", "Custom Co")
    old_admin_id = users(:admin).id
    post "/data/reset", params: { confirmation: "I KNOW WHAT I AM DOING", full: "1" }
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
      post "/data/reset", params: { confirmation: "I KNOW WHAT I AM DOING", full: "1" }
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
    post "/data/export"
    assert_response :success
    export_id = response.parsed_body["export_id"]
    assert export_id.present?

    perform_enqueued_jobs
    get "/data/export_status", params: { export_id: export_id }
    assert_equal "completed", response.parsed_body["state"]

    get "/data"
    assert_select "turbo-frame#backups #backups-table tbody tr", count: 1
    assert_select "#backups-table td", text: /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/
    ods_name = BackupExport.list.first[:files]["ods"]
    assert_select "#backups-table a[href=?]", "/data/download_backup?name=#{ERB::Util.url_encode(ods_name)}", text: /ODS file \(/
    assert_select "#backups-table a[href*='.zip']"

    # The form path polls: an export in flight marks the frame, a finished one does not.
    get "/data", params: { export_id: export_id }
    assert_select "turbo-frame#backups:not([data-poll-every])"
    BackupExportJob.write_status("pending1", { state: "running" })
    get "/data", params: { export_id: "pending1" }
    assert_select "turbo-frame#backups[data-poll-every] #export-data[disabled]", text: /#{I18n.t('ea.backup_working')}/

    get "/data/download_backup", params: { name: ods_name }
    assert_response :success
    assert_equal Ods::MIMETYPE, response.media_type

    path = Rails.root.join("tmp", "export-test-#{SecureRandom.hex(4)}.ods")
    File.binwrite(path, response.body)
    sheets = Ods.parse(path.to_s)
    assert_equal [ "Service Categories", "Services", "Providers", "Assistants", "Admins",
                   "Customers", "Appointment Statuses", "Appointments", "Blocked Periods", "Appointment Series",
                   "Working Plan Exceptions",
                   "Notifications", "Webhooks", "Consents", "Settings" ], sheets.keys
    customer_rows = sheets["Customers"]
    assert_includes customer_rows.first, "email"
    assert(customer_rows.drop(1).any? { |row| row.include?(users(:jx).email) })
  ensure
    FileUtils.rm_f(path) if path
  end

  test "appointments report downloads the range with the chosen statuses" do
    login_admin
    cancelled = Appointment.create!(
      start_datetime: "2026-07-21 10:00:00", end_datetime: "2026-07-21 10:45:00",
      provider: users(:zane), customer: users(:jx), service: services(:haircut), status: "Cancelled"
    )
    get "/data/report", params: { from: "2026-07-20", to: "2026-07-21" }
    assert_response :success
    assert_equal Ods::MIMETYPE, response.media_type
    path = Rails.root.join("tmp", "report-test-#{SecureRandom.hex(4)}.ods")
    File.binwrite(path, response.body)
    rows = Ods.parse(path.to_s)["Appointments"]
    assert_equal %w[Date Start End Duration Customer], rows.first.first(5)
    assert_equal 2, rows.size - 1
    assert_includes rows.last, "Cancelled"
    assert_includes rows.last, "45"

    get "/data/report", params: { from: "2026-07-20", to: "2026-07-21",
                                    status_ids: [ appointment_statuses(:booked).id ] }
    File.binwrite(path, response.body)
    assert_equal 1, Ods.parse(path.to_s)["Appointments"].size - 1

    get "/data/report", params: { from: "2026-07-20", to: "2026-07-21", status_ids: [ "" ] }
    File.binwrite(path, response.body)
    assert_equal 0, Ods.parse(path.to_s)["Appointments"].size - 1

    get "/data/report", params: { from: "2026-07-22", to: "2026-07-21" }
    assert_response :internal_server_error
    assert_not_nil cancelled
  ensure
    FileUtils.rm_f(path) if path
  end

  test "customer report downloads every customer with last-year counts" do
    login_admin
    get "/data/customer_report"
    assert_response :success
    assert_equal Ods::MIMETYPE, response.media_type
    path = Rails.root.join("tmp", "customer-report-test-#{SecureRandom.hex(4)}.ods")
    File.binwrite(path, response.body)
    rows = Ods.parse(path.to_s)["Customers"]
    assert_equal %w[Name Email], rows.first.first(2)
    assert_equal [ "Appointments in Last Year", "Providers", "Services", "Cancelled", "Late Cancel", "Rescheduled" ],
                 rows.first.last(6)
    assert_equal [ "JX" ], rows.drop(1).map(&:first)

    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    get "/data/customer_report"
    assert_response :forbidden
  ensure
    FileUtils.rm_f(path) if path
  end

  test "the page shows a heading for each report" do
    login_admin
    get "/data"
    assert_select "h6", text: "Appointment Report"
    assert_select "h6", text: "Customer Report"
    assert_select "form[action='/data/customer_report']"
  end

  test "backup downloads are admin only and validate the name" do
    login_admin
    perform_enqueued_jobs { post "/data/export" }
    ods_name = BackupExport.list.first[:files]["ods"]

    get "/data/download_backup", params: { name: "../../config/master.key" }
    assert_response :internal_server_error

    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    get "/data/download_backup", params: { name: ods_name }
    assert_response :forbidden
    get "/data"
    assert_response :forbidden
    post "/data/export"
    assert_response :forbidden
  end

  test "a private provider round-trips through export and import" do
    login_admin
    users(:zane).update!(is_private: true)
    upload_path = Rails.root.join("tmp", "private-#{SecureRandom.hex(4)}.ods")
    File.binwrite(upload_path, DataExport.generate)
    assert_includes Ods.parse(upload_path.to_s)["Providers"].first, "is_private"
    ResetDatabase.run

    ods_upload = Rack::Test::UploadedFile.new(upload_path, Ods::MIMETYPE)
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/data/start", params: { file: ods_upload, import_type: "ods",
                                      phases: TenToEight::Load::PHASES, create_providers: "1",
                                      days_back: 365, days_forward: 365 }
    end
    assert_response :success
    perform_enqueued_jobs

    assert User.providers.find_by(email: users(:zane).email).is_private
  ensure
    FileUtils.rm_f(upload_path) if upload_path
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
      post "/data/analyze", params: { file: ods_upload, import_type: "ods",
                                        days_back: 365, days_forward: 365 }
    end
    assert_response :success
    summary = response.parsed_body["summary"]
    assert_operator summary["customers"], :>=, 1
    assert_operator summary["appointments"], :>=, 1

    ods_upload = Rack::Test::UploadedFile.new(upload_path, Ods::MIMETYPE)
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/data/start", params: { file: ods_upload, import_type: "ods",
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
    post "/data/analyze", params: { file: upload, import_type: "ods",
                                      days_back: 21, days_forward: 21 }
    assert_response :internal_server_error
    assert_match(/Not an ODS spreadsheet/, response.parsed_body["message"])
  end

  test "the page and the cog menu call it Manage Data" do
    login_admin
    get "/data"
    assert_select "h4", text: "Manage Data"
    assert_select "#header .dropdown-item[href='/data']", text: /Manage Data/
    assert_select "title", text: /Manage Data/
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
    get "/data"
    assert_select "#phase-settings"
    assert_select "#phase-settings[checked]", count: 0
    assert_select "#phase-assistants[checked]", count: 0
    assert_select "#phase-admins[checked]", count: 0
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
      post "/data/start", params: {
        file: Rack::Test::UploadedFile.new(upload_path, Ods::MIMETYPE), import_type: "ods",
        phases: [ "customers" ], days_back: 365, days_forward: 365
      }
    end
    assert_equal "Changed Co", Setting.get("company_name")

    # With the settings phase every exported key restores, integrations included.
    post "/data/start", params: {
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
    post "/data/analyze", params: {
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
    post "/data/start", params: {
      file: Rack::Test::UploadedFile.new(ods_path, Ods::MIMETYPE), import_type: "ods",
      phases: [ "services" ], days_back: 21, days_forward: 21
    }
    perform_enqueued_jobs
    assert_not services(:haircut).reload.picture.attached?

    # With the zip the referenced picture attaches.
    post "/data/start", params: {
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

  test "staff passwords round-trip through export and import as stored hashes" do
    login_admin
    assistant = User.assistants.first
    assistant.create_settings!(username: "assist1", password: Passwords.hash("assistpass1"),
                               notifications: false)
    admin2 = User.create!(name: "Second Admin", email: "admin2@example.org",
                          timezone: "Europe/London", role: Role.find_by!(slug: Role::ADMIN))
    admin2.create_settings!(username: "admin2", password: Passwords.hash("adminpass2"), notifications: false)

    ods_path = Rails.root.join("tmp", "pw-roundtrip-#{SecureRandom.hex(4)}.ods")
    File.binwrite(ods_path, DataExport.generate)

    sheets = Ods.parse(ods_path.to_s)
    %w[Providers Assistants Admins].each do |sheet|
      assert_includes sheets[sheet].first, "password_hash", "#{sheet} sheet misses password_hash"
    end
    hashes = sheets["Admins"].drop(1).flat_map { |row| row.last.to_s }
    assert(hashes.none? { |value| value.include?("adminpass2") }, "plain password leaked into export")

    admin2.settings.update(password: Passwords.hash("changed"))
    assistant.settings.update(password: Passwords.hash("changed"))
    zane_settings = users(:zane).settings
    zane_settings.update(password: Passwords.hash("changed"))

    post "/data/start", params: {
      file: Rack::Test::UploadedFile.new(ods_path, Ods::MIMETYPE), import_type: "ods",
      phases: %w[providers assistants admins], days_back: 21, days_forward: 21
    }
    perform_enqueued_jobs

    assert Passwords.verify(nil, "janedoe1", zane_settings.reload.password)
    assert Passwords.verify(nil, "assistpass1", assistant.settings.reload.password)
    assert Passwords.verify(nil, "adminpass2", admin2.settings.reload.password)

    # Deleted staff come back with working logins when creation is allowed.
    AssistantProviderLink.where(id_users_assistant: assistant.id).delete_all
    assistant.settings.destroy
    assistant.destroy
    admin2.settings.destroy
    admin2.destroy

    post "/data/start", params: {
      file: Rack::Test::UploadedFile.new(ods_path, Ods::MIMETYPE), import_type: "ods",
      phases: %w[providers assistants admins], create_providers: "1", days_back: 21, days_forward: 21
    }
    perform_enqueued_jobs

    post "/logout"
    post "/login/validate", params: { username: "admin2", password: "adminpass2" }
    assert_equal true, response.parsed_body["success"]
  ensure
    FileUtils.rm_f(ods_path) if ods_path
  end
end

# The manage data page as forms with polling frames.
class ImportFormsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    TenToEightImportJob.status_store = ActiveSupport::Cache::MemoryStore.new
    BackupExportJob.status_store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    TenToEightImportJob.status_store = nil
    BackupExportJob.status_store = nil
  end

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def ods_upload
    path = Rails.root.join("tmp", "forms-test-#{SecureRandom.hex(4)}.ods")
    File.binwrite(path, DataExport.generate)
    Rack::Test::UploadedFile.new(path, Ods::MIMETYPE)
  end

  test "the page has the import, reset and export forms and no page script" do
    login_admin
    get "/data"
    assert_select "form#import-form[action='/data/start'][enctype='multipart/form-data'] button#analyze-import[formaction='/data/analyze']"
    assert_select "form#import-form input[name='phases[]'][value=customers][checked]"
    assert_select "form#import-form #images-zip-wrapper[data-visible-when='import_type=ods']"
    assert_select "form#reset-form[action='/data/reset'] #reset-database[data-enabled-when]"
    assert_select "turbo-frame#backups form[action='/data/export'] #export-data"
    assert_select "turbo-frame#import-status:not([data-poll-every])"
    assert_select "script[src*='pages/import']", count: 0
  end

  test "analyze from the form shows the summary on the page once" do
    login_admin
    post "/data/analyze", params: { form: "1", import_type: "ods", file: ods_upload, days_back: 21, days_forward: 21 }
    assert_redirected_to "/data"
    follow_redirect!
    assert_select "#import-results", text: /customers: \d+/
    get "/data"
    assert_select "#import-results", count: 0
  end

  test "start from the form polls the status frame until the import completes" do
    login_admin
    post "/data/start", params: { form: "1", import_type: "ods", file: ods_upload, phases: [ "customers" ], days_back: 21, days_forward: 21 }
    assert_response :redirect
    import_id = response.location[/import_id=(\w+)/, 1]
    get "/data", params: { import_id: import_id }
    assert_select "turbo-frame#import-status[data-poll-every='2000'] #import-results", text: /#{I18n.t('ea.import_running')}/

    perform_enqueued_jobs
    get "/data", params: { import_id: import_id }
    assert_select "turbo-frame#import-status:not([data-poll-every]) #import-results.alert-success", text: /#{I18n.t('ea.import_complete')}/
    assert_select "#import-results", text: /#{I18n.t('ea.customers')}: \d+ #{I18n.t('ea.created')}/
  end

  test "a bad file from the form comes back with the message; reset needs the phrase" do
    login_admin
    csv = Rack::Test::UploadedFile.new(StringIO.new("a,b\n1,2\n"), "text/csv", original_filename: "x.csv")
    post "/data/analyze", params: { form: "1", import_type: "ods", file: csv }
    assert_redirected_to "/data"
    follow_redirect!
    assert_select "#import-results.alert-danger"

    post "/data/reset", params: { form: "1", confirmation: "nope" }
    assert_redirected_to "/data"
    follow_redirect!
    assert_select "#import-results.alert-danger", text: /I KNOW WHAT I AM DOING/
  end
end
