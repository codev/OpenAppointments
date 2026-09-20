require "test_helper"

# The Waiting List page: who is waiting for what, reached from Customers.
class WaitlistPageTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "the customers page links to the list and the list shows the live signups" do
    login_admin
    get "/customers"
    assert_select "a[href='/waitlist']", text: /#{I18n.t('ea.waitlist')}/

    chosen = WaitlistEntry.create!(name: "Chosen Person", email: "chosen@example.org", phone: "07700900001",
                                   service: services(:haircut), provider: users(:zane), notices_sent: 2)
    WaitlistEntry.create!(name: "Any Person", email: "any@example.org", service: services(:group_session))
    WaitlistEntry.create!(name: "Gone Person", email: "gone@example.org", service: services(:haircut), expires_at: 1.minute.ago)
    get "/waitlist"
    assert_response :success
    assert_select "h4", text: I18n.t("ea.waitlist")
    assert_select "#waitlist-entries tbody tr", 2
    assert_select "#waitlist-entries tbody tr:first-child td", text: "Chosen Person"
    assert_select "#waitlist-entries tbody tr:first-child td", text: /chosen@example.org/
    assert_select "#waitlist-entries tbody tr:first-child td", text: "Trim Cut"
    assert_select "#waitlist-entries tbody tr:first-child td", text: "Zane"
    assert_select "#waitlist-entries tbody tr:first-child td", text: "2"
    assert_select "#waitlist-entries tbody tr:nth-child(2) td", text: I18n.t("ea.any_provider")
    assert_select "#waitlist-entries td", text: "Gone Person", count: 0
    assert_select "form[action='/waitlist/#{chosen.id}'] input[name=_method][value=delete]"
  end

  test "an empty list says so and a signup can be removed" do
    login_admin
    get "/waitlist"
    assert_select "#waitlist-entries", 0
    assert_includes response.body, I18n.t("ea.waitlist_empty")

    entry = WaitlistEntry.create!(name: "W", email: "w@example.org", service: services(:haircut))
    delete "/waitlist/#{entry.id}"
    assert_redirected_to "/waitlist"
    assert_nil WaitlistEntry.find_by(id: entry.id)
  end

  test "the page needs a login" do
    get "/waitlist"
    assert_redirected_to "/login"
  end
end
