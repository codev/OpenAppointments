require "test_helper"

# Admin Activity page: newest first, filter by kind, admins only, linked from
# the header.
class ActivityPageTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  setup do
    Current.reset
    @booked = Activity.record(:appointment_booked, summary: "Haircut for Jx with Zane, Mon 20 Jul 2026 10:00-10:30",
                                                   appointment: appointments(:upcoming), details: "Status Booked")
    @sent = Activity.record(:message_sent, summary: "Reminder to customer by Email, c@example.org")
  end

  test "admin sees the events newest first with the actor and a link to the customer" do
    login_admin
    get "/activity"
    assert_response :success
    assert_select "tr.activity-event", 2
    assert_select "tr.activity-event:first-child td", text: /Reminder to customer/
    assert_select "a[href=?]", "/customers/#{users(:jx).id}/messages"
    assert_select "a[href=?] i.fa-user", "/customers/#{users(:jx).id}/edit"
    assert_select "tr.activity-event span.badge.text-bg-success", text: "Booked"
    assert_select "tr.activity-event span.badge.text-bg-info", text: "Message sent"
    assert_select "tr.activity-event td i.activity-joiner", text: "with"
    assert_select "#activity-refresh[checked]"
  end

  test "the kind filter narrows the list" do
    login_admin
    get "/activity", params: { kind: "appointment_booked" }
    assert_select "tr.activity-event", 1
    assert_select "tr.activity-event td", text: /Haircut for Jx/
  end

  test "a bad kind is ignored and refresh can be switched off" do
    login_admin
    get "/activity", params: { kind: "nonsense", refresh: "0" }
    assert_response :success
    assert_select "tr.activity-event", 2
    assert_select "#activity-refresh[checked]", 0
  end

  test "provider is forbidden" do
    login_provider
    get "/activity"
    assert_response :forbidden
  end

  test "the header links to the page for admins only" do
    login_admin
    get "/appointments"
    assert_select "a[href=?]", "/activity"
    login_provider
    get "/appointments"
    assert_select "a[href=?]", "/activity", 0
  end
end
