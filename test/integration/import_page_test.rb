require "test_helper"

class ImportPageTest < ActionDispatch::IntegrationTest
  setup { TenToEightImportJob.status_store = ActiveSupport::Cache::MemoryStore.new }
  teardown { TenToEightImportJob.status_store = nil }

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

  test "export downloads a dated ODS with all the sheets" do
    login_admin
    get "/import/export"
    assert_response :success
    assert_equal Ods::MIMETYPE, response.media_type
    assert_includes response.headers["Content-Disposition"],
                    "#{Date.current.strftime('%Y-%m-%d')}-OpenAppointments.ods"

    path = Rails.root.join("tmp", "export-test-#{SecureRandom.hex(4)}.ods")
    File.binwrite(path, response.body)
    sheets = Ods.parse(path.to_s)
    assert_equal [ "Service Categories", "Services", "Providers", "Secretaries", "Admins",
                   "Customers", "Appointments", "Blocked Periods", "Settings" ], sheets.keys
    customer_rows = sheets["Customers"]
    assert_includes customer_rows.first, "email"
    assert(customer_rows.drop(1).any? { |row| row.include?(users(:jx).email) })
  ensure
    FileUtils.rm_f(path) if path
  end

  test "an exported ODS analyzes and imports back after a reset" do
    login_admin
    provider_email = users(:zane).email
    customer_email = users(:jx).email
    service_name = services(:haircut).name
    get "/import/export"
    upload_path = Rails.root.join("tmp", "roundtrip-#{SecureRandom.hex(4)}.ods")
    File.binwrite(upload_path, response.body)
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
end
