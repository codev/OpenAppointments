require "test_helper"

class BackendCrudTest < ActionDispatch::IntegrationTest
  PAGES = %w[customers services service_categories providers secretaries admins
             blocked_periods webhooks].freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  def login_customer
    customer = users(:jx)
    customer.create_settings!(username: "jamesdoe", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jamesdoe", password: "customer1" }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "backend pages require session" do
    PAGES.each do |page|
      get "/#{page}"
      assert_redirected_to "/login", "expected /#{page} to redirect"
    end
  end

  test "backend pages render for admins" do
    login_admin
    PAGES.each do |page|
      get "/#{page}"
      assert_response :success, "expected /#{page} to render"
      assert_match "window.vars", response.body
    end
  end

  test "backend pages forbid the customer role" do
    login_customer
    PAGES.each do |page|
      get "/#{page}"
      assert_response :forbidden, "expected /#{page} to be forbidden"
    end
  end

  test "services store and search round trip" do
    login_admin

    post "/services/store", params: {
      service: { name: "Colour Consult", duration: 45, price: 0, currency: "GBP",
                 providers: [ users(:zane).id ] }
    }
    assert_response :success
    body = response.parsed_body
    assert_equal true, body["success"]
    service_id = body["id"]
    assert service_id.present?
    assert_equal [ users(:zane).id ], Service.find(service_id).provider_links.map(&:id_users)

    post "/services/search", params: { keyword: "Colour Consult" }
    assert_response :success
    rows = response.parsed_body
    assert_equal 1, rows.length
    assert_equal "Colour Consult", rows.first["name"]
    assert_equal [ users(:zane).id ], rows.first["providers"]
  end

  test "blocked periods store and search round trip" do
    login_admin

    post "/blocked_periods/store", params: {
      blocked_period: { name: "Xmas Break", start_datetime: "2026-12-24 00:00:00",
                        end_datetime: "2026-12-28 23:59:59", notes: "Closed" }
    }
    assert_response :success
    body = response.parsed_body
    assert_equal true, body["success"]
    assert body["id"].present?

    post "/blocked_periods/search", params: { keyword: "Xmas" }
    assert_response :success
    rows = response.parsed_body
    assert_equal 1, rows.length
    assert_equal "Xmas Break", rows.first["name"]
    assert_equal "2026-12-24 00:00:00", rows.first["start_datetime"]
  end

  test "provider store persists settings, services and working plan exceptions" do
    login_admin
    company_plan = { monday: { start: "09:00", end: "17:00", breaks: [] } }.to_json
    Setting.set("company_working_plan", company_plan)

    post "/providers/store", params: {
      provider: {
        name: "Pat Stylist", email: "pat@example.org",
        services: [ services(:haircut).id ],
        settings: {
          username: "patstylist", password: "patstylist1", notifications: "1",
          calendar_view: "default",
          working_plan_exceptions: { "0" => { startDate: "2026-08-01", endDate: "2026-08-01",
                                              startTime: "10:00", endTime: "14:00" } }.values.to_json
        }
      }
    }
    assert_response :success
    body = response.parsed_body
    assert_equal true, body["success"]

    provider = User.providers.find(body["id"])
    assert_equal "patstylist", provider.settings.username
    assert Passwords.verify(nil, "patstylist1", provider.settings.password)
    assert_equal company_plan, provider.settings.working_plan,
                 "working_plan should default to the company plan"
    assert_equal [ services(:haircut).id ], provider.provider_service_links.map(&:id_services)
    assert_equal 1, WorkingPlanException.where(id_users_provider: provider.id).count

    # New providers without a password are rejected, as in EA.
    post "/providers/store", params: {
      provider: { name: "No Password", email: "nopass@example.org",
                  settings: { username: "nopassword" } }
    }
    assert_equal false, response.parsed_body["success"]
  end

  test "admins cannot delete their own account" do
    login_admin

    post "/admins/destroy", params: { admin_id: users(:admin).id }
    body = response.parsed_body
    assert_equal false, body["success"]
    assert_match(/cannot delete your own account/i, body["message"])
    assert User.exists?(users(:admin).id)
  end

  test "unavailabilities endpoints work without a page" do
    login_admin

    post "/unavailabilities/store", params: {
      unavailability: { start_datetime: "2026-07-21 09:00:00", end_datetime: "2026-07-21 11:00:00",
                        notes: "Dentist", id_users_provider: users(:zane).id }
    }
    assert_response :success
    body = response.parsed_body
    assert_equal true, body["success"]
    record = Appointment.unavailabilities.find(body["id"])
    assert record.is_unavailability

    post "/unavailabilities/search", params: { keyword: "Dentist" }
    assert_response :success
    assert_equal 1, response.parsed_body.length

    get "/unavailabilities/find", params: { unavailability_id: record.id }
    assert_response :success
    assert_equal "Dentist", response.parsed_body["notes"]
  end
end
