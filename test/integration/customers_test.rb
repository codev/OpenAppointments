require "test_helper"

class CustomersTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  test "the conversation channel choice keeps All Providers under staff terminology" do
    Setting.set("provider_label", "Stylist")
    Setting.set("provider_label_plural", "Stylists")
    login_admin
    get "/customers/#{users(:jx).id}/edit"
    assert_select "#message-channel option[value='all']", text: "All Providers"
    get "/appointments"
    assert_select "select#filter-provider option", text: "All Stylists"
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

  test "merging moves appointments and messages to the customer with the typed phone or email and deletes the record" do
    login_admin
    kept = User.create!(name: "Kept", email: "kept@example.org", role: roles(:customer))
    gone = User.create!(name: "Gone", phone_number: "+447700900777", address: "1 Lane", notes: "Allergic to X", role: roles(:customer))
    appointment = Appointment.create!(provider: users(:zane), customer: gone, service: services(:haircut), status: "Booked",
                                      start_datetime: "2026-08-03 11:00:00", end_datetime: "2026-08-03 11:30:00")
    message = Message.create!(direction: "incoming", channel: "email", status: "received", customer_id: gone.id, body: "Hi")

    get "/customers/#{gone.id}/edit"
    assert_select "form#merge-customer input#merge-target"

    post "/customers/#{gone.id}/merge", params: { target: "nobody@example.org" }
    assert_redirected_to "/customers/#{gone.id}/edit"
    assert_equal I18n.t("ea.merge_customer_not_found"), flash[:alert]

    post "/customers/#{gone.id}/merge", params: { target: "kept@example.org" }
    assert_redirected_to "/customers/#{kept.id}/edit"
    assert_equal I18n.t("ea.customer_merged"), flash[:notice]
    assert_nil User.find_by(id: gone.id)
    assert_equal kept.id, appointment.reload.id_users_customer
    assert_equal kept.id, message.reload.customer_id
    kept.reload
    assert_equal [ "+447700900777", "1 Lane", "Allergic to X" ], [ kept.phone_number, kept.address, kept.notes ]

    other = User.create!(name: "Other", phone_number: "07700 900888", role: roles(:customer))
    post "/customers/#{kept.id}/merge", params: { target: "+447700900888" }
    assert_redirected_to "/customers/#{other.id}/edit"
  end
end
