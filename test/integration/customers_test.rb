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
    get "/customers/#{users(:jx).id}/messages"
    assert_select "#customer-message-composer .channel-option[data-value='all']", text: "All"
    get "/appointments"
    assert_select "#provider-filter button[data-tick=all]", text: "All Stylists"
    assert_select "#provider-filter button[data-tick=clear]", text: "Clear Stylists"
  end

  test "with email and one SMS provider the send to every channel choice still reads All" do
    { "messages_twilio_enabled" => "1", "messages_twilio_account_sid" => "AC1", "messages_twilio_auth_token" => "token",
      "messages_twilio_from" => "+15005550006" }.each { |name, value| Setting.set(name, value) }
    login_admin
    get "/customers/#{users(:jx).id}/messages"
    assert_select "#customer-message-composer .channel-option", count: 3
    assert_select "#customer-message-composer .channel-option.channel-twilio[data-value='twilio']", text: "Twilio"
    assert_select "#customer-message-composer .channel-option[data-value='all']", text: "All"
    assert_select "#customer-message-composer[style*='var(--channel-email)'][style*='var(--channel-twilio)']"
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

  test "Details and Messages are separate sections with their own URLs" do
    login_admin
    jx = users(:jx).id
    get "/customers/#{jx}/edit"
    assert_select "#customers-page.editing"
    assert_select "#customers-page .record-details > h4", count: 0
    assert_select "#customer-heading h4", text: "Customer"
    assert_select "#customer-heading h4 + #customer-sections.ms-auto"
    assert_select "#customer-sections .nav-link.active[aria-current=page]", text: "Details"
    assert_select "#customer-sections a.nav-link[href=?][data-turbo-frame=customers_record][data-turbo-action=advance]",
                  "/customers/#{jx}/messages", text: "Messages"
    assert_select "form.crud-form"
    assert_select "#customer-appointments .appointment-row a[href='/calendar/reschedule/abc123def456'] strong",
                  text: "Trim Cut - Zane"
    assert_select "#customer-appointments small", text: "20/07/2026 10:00 am"
    assert_select "#customer-messages", count: 0

    get "/customers/#{jx}/messages"
    assert_select "#customers-page.editing"
    assert_select "#customer-sections .nav-link.active[aria-current=page]", text: "Messages"
    assert_select "#customer-sections a.nav-link[href=?]", "/customers/#{jx}/edit", text: "Details"
    assert_select "form.crud-form", count: 0
    assert_select "#customer-messages[data-customer-id=?][data-scroll=true]", jx.to_s
    assert_select "#customer-message-composer input#message-channel[type=hidden]"
    assert_select "#customer-message-composer .dropup #message-channel-button", text: "Select One"
    assert_select "script[src*='components/customer_messages']"
  end

  test "a new customer has only the details and the deep links in sent notifications open the sections" do
    login_admin
    get "/customers/new"
    assert_select "#customer-sections", count: 0
    assert_select "form.crud-form"

    get "/customers", params: { customer_id: users(:jx).id, section: "messages" }
    assert_redirected_to "/customers/#{users(:jx).id}/messages"
    get "/customers", params: { customer_id: users(:jx).id }
    assert_redirected_to "/customers/#{users(:jx).id}/edit"
    get "/customers/#{users(:jx).id}/edit", params: { section: "messages" }
    assert_redirected_to "/customers/#{users(:jx).id}/messages"
  end

  test "the messages section needs access to the customer" do
    get "/customers/#{users(:jx).id}/messages"
    assert_redirected_to "/login"
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

  test "do not contact is saved from the details and warns on the messages section, which can still send" do
    login_admin
    jx = users(:jx)
    get "/customers/#{jx.id}/messages"
    assert_select "#do-not-contact-warning", count: 0

    get "/customers/#{jx.id}/edit"
    assert_select "input[type=checkbox][name='customer[do_not_contact]']:not([checked])"
    patch "/customers/#{jx.id}", params: { customer: { do_not_contact: "1" } }
    assert jx.reload.do_not_contact

    get "/customers/#{jx.id}/edit"
    assert_select "input[type=checkbox][name='customer[do_not_contact]'][checked]"
    get "/customers/#{jx.id}/messages"
    assert_select "#do-not-contact-warning", text: I18n.t("ea.do_not_contact_warning")
    assert_select "#customer-message-composer #send-message"

    patch "/customers/#{jx.id}", params: { customer: { do_not_contact: "0" } }
    assert_not jx.reload.do_not_contact
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
