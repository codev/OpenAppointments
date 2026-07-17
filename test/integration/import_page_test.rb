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
    post "/import/reset", params: { confirmation: "nope" }
    assert_response :internal_server_error
    assert Appointment.any?

    post "/import/reset", params: { confirmation: "RESET" }
    assert_response :success
    assert_equal 0, Appointment.count
    assert User.admins.any?
  end

  test "the import strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[import_data import_hint analyze start_import create_providers days_back days_forward
         reset_database reset_database_warning reset_confirmation_hint].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
