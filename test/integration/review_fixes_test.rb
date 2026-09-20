require "test_helper"

# Regressions from the 2.0.0 code review, one case per finding.
class ReviewFixesTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  test "customer search works for a provider under limited access and only lists their customers" do
    Setting.set("limit_customer_access", "1")
    other = User.create!(name: "Nobody", email: "nobody@example.org", role: users(:jx).role)
    login_provider
    post "/customers/search", params: { keyword: "", limit: 50 }
    assert_response :success
    assert_equal [ users(:jx).id ], response.parsed_body.map { |row| row["id"] }
    get "/customers"
    assert_select ".customer-row[data-id=?]", other.id.to_s, count: 0
  end

  test "a record error raised while saving dependent data re-renders the form with the message" do
    login_admin
    exception = WorkingPlanException.create!(id_users_provider: users(:zane).id, start_date: "2026-09-01", end_date: "2026-09-01",
                                             start_time: "10:00", end_time: "14:00", breaks: "[]")
    stale = [ { id: exception.id, startDate: "2026-09-01", endDate: "2026-09-01", startTime: "10:00", endTime: "14:00", breaks: [] } ].to_json
    exception.destroy!
    patch "/providers/#{users(:zane).id}", params: { provider: { settings: { working_plan_exceptions: stale } } }
    assert_response :unprocessable_entity
    assert_select "form.crud-form .form-message", text: /Couldn't find WorkingPlanException/
  end

  test "a failed provider save keeps the typed working plan and exceptions in the form" do
    login_admin
    plan = { monday: { start: "11:00", end: "15:00", breaks: [] } }.to_json
    exceptions = [ { startDate: "2026-09-02", endDate: "2026-09-02", startTime: "09:00", endTime: "12:00", breaks: [] } ].to_json
    patch "/providers/#{users(:zane).id}", params: {
      provider: { settings: { username: "janedoe", password: "password1", password_confirmation: "other",
                              working_plan: plan, working_plan_exceptions: exceptions } }
    }
    assert_response :unprocessable_entity
    assert_select "#working-plan-json[value=?]", plan
    assert_select "#working-plan-exceptions-json[value=?]", exceptions
    assert_not_equal plan, users(:zane).settings.reload.working_plan
  end

  test "user webhooks carry the role specific rows" do
    assert Webhooks.to_row(users(:zane)).key?("settings")
    assert Webhooks.to_row(users(:zane)).key?("services")
    assert Webhooks.to_row(users(:sam)).key?("providers")
    assert Webhooks.to_row(users(:admin)).key?("settings")
    assert_not Webhooks.to_row(users(:jx)).key?("settings")
  end

  test "the LDAP import refuses an email already used by the role and ignores ldap_dn while LDAP is off" do
    login_admin
    post "/ldap_settings/import", params: { role_slug: "provider", user: { name: "Dup", email: users(:zane).email, phone_number: "1", ldap_dn: "cn=d" },
                                            settings: { username: "dup", password: "password1" } }
    follow_redirect!
    assert_select ".alert-danger", text: /already in use/
    assert_equal 1, User.providers.where(email: users(:zane).email).count
  end

  test "create needs the add privilege and new is gated the same way" do
    role = Role.find_by!(slug: Role::ADMIN)
    role.update!(services: Role::PRIV_VIEW | Role::PRIV_EDIT | Role::PRIV_DELETE) # no add bit
    login_admin
    get "/services/new"
    assert_response :forbidden
    post "/services", params: { service: { name: "Nope", duration: 30 } }
    assert_response :forbidden
    patch "/services/#{services(:haircut).id}", params: { service: { name: "Still editable" } }
    assert_redirected_to "/services?selected=#{services(:haircut).id}"
  end

  test "the API token can be blanked from its page while other secrets keep their stored value" do
    login_admin
    Setting.set("api_token", "tok")
    Setting.set("google_client_secret", "sekrit")
    post "/api_settings/save", params: { settings: { api_token: "" } }
    assert_equal "", Setting.get("api_token")
    post "/google_calendar_settings/save", params: { settings: { google_client_secret: "", google_client_id: "id" } }
    assert_equal "sekrit", Setting.get("google_client_secret")
  end

  test "the booking settings form refuses no visible field and no required field" do
    login_admin
    post "/booking_settings/save", params: { settings: { display_email: "0", display_phone_number: "0", display_address: "0",
                                                          display_city: "0", display_zip_code: "0", display_notes: "0" } }
    assert_redirected_to "/booking_settings"
    follow_redirect!
    assert_select ".alert-danger", text: I18n.t("ea.at_least_one_field")

    post "/booking_settings/save", params: { settings: { display_email: "1", require_email: "0", require_phone_number: "0", require_phone_or_email: "0" } }
    follow_redirect!
    assert_select ".alert-danger", text: I18n.t("ea.at_least_one_field_required")

    post "/booking_settings/save", params: { settings: { display_email: "1", require_phone_or_email: "1" } }
    follow_redirect!
    assert_select ".alert-success"
  end

  test "appointments without a status stay in the day view" do
    login_admin
    Appointment.create!(id_users_provider: users(:zane).id, id_users_customer: users(:jx).id, id_services: services(:haircut).id,
                        start_datetime: "2026-07-20 15:00", end_datetime: "2026-07-20 15:30", notes: "No status")
    get "/appointments", params: { date: "2026-07-20" }
    assert_select ".day-entry-appointment", text: /JX - Trim Cut/, count: 2
  end

  test "the general settings page offers to remove a saved logo and removes it" do
    login_admin
    Setting.set("company_logo", "data:image/png;base64,AAAA")
    get "/general_settings"
    assert_select "#company-logo-preview[src^='/company_logo?v=']:not([hidden])"
    assert_select "#remove-company-logo[name=remove_company_logo]"
    post "/general_settings/save", params: { settings: { company_name: "Test Company" }, remove_company_logo: "1" }
    assert_equal "", Setting.get("company_logo")
    get "/general_settings"
    assert_select "#remove-company-logo", count: 0
  end

  test "the account save copes with a JSON caller omitting the username" do
    login_admin
    post "/account/save", params: { account: { name: "Edson", email: users(:admin).email } }
    assert_response :success
  end

  test "the appointment dialog asks the update question when editing" do
    login_admin
    get "/appointments/new"
    assert_select "#appointment-form[data-ask-notify-question=notify_users_on_create_question]"
    get "/appointments/#{appointments(:upcoming).id}/edit"
    assert_select "#appointment-form[data-ask-notify-question=notify_users_on_update_question]"
  end

  test "paging counts without plucking every id unless a record is selected" do
    login_admin
    role = Role.find_by!(slug: Role::CUSTOMER)
    25.times { |i| User.create!(name: "Pager #{i}", email: "pg#{i}@example.org", role: role) }
    queries = []
    ActiveSupport::Notifications.subscribed(->(*, payload) { queries << payload[:sql] }, "sql.active_record") { get "/customers" }
    assert queries.none? { |sql| sql =~ /SELECT "users"."id" FROM "users"/ }, "ids plucked on a plain index"
    assert_select ".customer-row", count: 20
  end
end
