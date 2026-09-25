require "test_helper"

class CustomersTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  test "the conversation channel choice reads All and staff terminology stays on the stylist filter" do
    Setting.set("provider_label", "Stylist")
    Setting.set("provider_label_plural", "Stylists")
    login_admin
    get "/customers/#{users(:jx).id}/edit"
    assert_select "#message-channel option[value='all']", text: "All"
    get "/appointments"
    assert_select "select#filter-provider option", text: "All Stylists"
  end

  test "with email and one SMS provider the send to every channel choice still reads All" do
    { "messages_twilio_enabled" => "1", "messages_twilio_account_sid" => "AC1", "messages_twilio_auth_token" => "token",
      "messages_twilio_from" => "+15005550006" }.each { |name, value| Setting.set(name, value) }
    login_admin
    get "/customers/#{users(:jx).id}/edit"
    assert_select "#message-channel option", count: 4
    assert_select "#message-channel option[value='all']", text: "All"
  ensure
    Setting.set("messages_twilio_enabled", "0")
  end

  test "index lists customers with unread badges and the record links to edit" do
    login_admin
    Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                    customer_id: users(:jx).id, body: "Hello", status: "received")
    get "/customers"
    assert_select ".customer-row[data-id=?] .unread-badge", users(:jx).id.to_s, text: "1"
    assert_select ".customer-row small", text: "j@example.org, +447700900321"
    assert_select "a[href=?]", "/customers/#{users(:jx).id}/edit"
    assert_select "#add-customer"
  end

  test "the deep link redirects to edit and the edit page carries the messages panel and history" do
    login_admin
    get "/customers", params: { customer_id: users(:jx).id, section: "messages" }
    assert_redirected_to "/customers/#{users(:jx).id}/edit?section=messages"
    follow_redirect!
    assert_select "#customers-page.editing"
    assert_select "#customer-messages[data-customer-id=?][data-scroll=true]", users(:jx).id.to_s
    assert_select "#customer-message-composer select#message-channel"
    assert_select "#customer-appointments .appointment-row a[href='/calendar/reschedule/abc123def456'] strong",
                  text: "Trim Cut - Zane"
    assert_select "#customer-appointments small", text: "20/07/2026 10:00 am"
    assert_select "script[src*='components/customer_messages']"
  end

  test "the appointment list labels each status and greys the ones that freed their slot" do
    base = { provider: users(:zane), customer: users(:jx), service: services(:haircut) }
    late = Appointment.create!(**base, start_datetime: Time.new(2026, 7, 21, 10, 0, 0), end_datetime: Time.new(2026, 7, 21, 10, 30, 0))
    late.update!(appointment_status: appointment_statuses(:late_cancel))
    missed = Appointment.create!(**base, start_datetime: Time.new(2026, 7, 22, 10, 0, 0), end_datetime: Time.new(2026, 7, 22, 10, 30, 0))
    missed.update!(appointment_status: appointment_statuses(:no_show))
    appointment_statuses(:late_cancel).update!(name: "Late Cancellation")
    login_admin
    get "/customers/#{users(:jx).id}/edit"

    assert_select "#customer-appointments .appointment-row[data-id=?]", late.id.to_s do
      assert_select ".appointment-status", text: "Late Cancellation"
    end
    assert_select "#customer-appointments .appointment-row.appointment-freed[data-id=?]", late.id.to_s
    assert_select "#customer-appointments .appointment-row[data-id=?]:not(.appointment-freed) .appointment-status",
                  missed.id.to_s, text: "No Show"
    assert_select "#customer-appointments .appointment-row[data-id=?]:not(.appointment-freed) .appointment-status",
                  appointments(:upcoming).id.to_s, text: "Booked"
  end

  test "new has no history or messages; create and update save custom fields and notes" do
    login_admin
    Setting.set("display_custom_field_1", "1")
    get "/customers/new"
    assert_select "#customer-messages", count: 0
    assert_select "#customer-appointments p", text: I18n.t("ea.no_records_found")
    assert_select "input[name='customer[custom_field_1]']"

    post "/customers", params: { customer: { name: "Pat", email: "pat@example.org", language: "english",
                                             timezone: "UTC", custom_field_1: "they/them", notes: "n" } }
    pat = User.customers.find_by!(email: "pat@example.org")
    assert_redirected_to "/customers?selected=#{pat.id}"
    assert_equal "they/them", pat.custom_field_1

    patch "/customers/#{pat.id}", params: { customer: { notes: "Prefers mornings" } }
    assert_equal "Prefers mornings", pat.reload.notes
    delete "/customers/#{pat.id}"
    assert_not User.exists?(pat.id)
  end

  test "a blank name is refused" do
    login_admin
    post "/customers", params: { customer: { name: "", email: "x@example.org" } }
    assert_response :unprocessable_entity
    assert_select "input.is-invalid[name='customer[name]']"
  end

  test "limited access hides other providers' customers and the add button from providers" do
    Setting.set("limit_customer_access", "1")
    other = User.create!(name: "Nobody", email: "nobody@example.org", role: users(:jx).role)
    login_provider
    get "/customers"
    assert_select ".customer-row[data-id=?]", users(:jx).id.to_s
    assert_select ".customer-row[data-id=?]", other.id.to_s, count: 0
    assert_select "#add-customer", count: 0
    get "/customers/#{other.id}/edit"
    assert_response :forbidden
    get "/customers/new"
    assert_response :forbidden
    patch "/customers/#{other.id}", params: { customer: { name: "x" } }
    assert_response :forbidden
    get "/customers/#{users(:jx).id}/edit"
    assert_response :success
  end

  test "search still answers JSON for the appointments modal and create for the LDAP import" do
    login_admin
    post "/customers/search", params: { keyword: "JX", limit: 50 }
    assert_equal [ "JX" ], response.parsed_body.map { |row| row["name"] }
    assert_equal "1", response.headers["X-Total-Count"]

    post "/customers", params: { customer: { name: "Ldap", email: "ldap@example.org", language: "english" } }, as: :json
    assert_equal true, response.parsed_body["success"]

    post "/customers/store", params: { customer: { name: "x" } }
    assert_response :not_found
  end
end
