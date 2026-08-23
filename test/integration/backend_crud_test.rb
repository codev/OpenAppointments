require "test_helper"

class BackendCrudTest < ActionDispatch::IntegrationTest
  PAGES = %w[customers services service_categories providers assistants admins
             blocked_periods webhooks].freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "the old secretaries page URL redirects to assistants" do
    login_admin
    get "/secretaries"
    assert_redirected_to "/assistants"
  end

  test "the assistant role and language carry no secretary naming" do
    assert Role.exists?(slug: "assistant")
    assert_not Role.exists?(slug: "secretary")
    I18n.available_locales.each do |locale|
      %w[assistants assistant_saved delete_assistant].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
      assert_nil I18n.t("ea.secretaries", locale: locale, fallback: false, default: nil),
                 "old ea.secretaries still present in #{locale}"
    end
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

  test "the header shows the user top right with a cog settings menu, no footer booking link" do
    login_admin
    get "/calendar"
    assert_select "#header-logo small#header-user", text: users(:admin).name
    assert_select "#header a.dropdown-toggle[aria-label=?]", I18n.t("ea.settings") do |links|
      assert_select links.first, "i.fa-cog"
      assert_equal "", links.first.children.select(&:text?).map(&:text).join.strip
    end
    assert_select "#footer a", text: I18n.t("ea.go_to_booking_page"), count: 0
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
