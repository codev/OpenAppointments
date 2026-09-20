require "test_helper"

class MessagesPagesTest < ActionDispatch::IntegrationTest
  MESSAGES_PAGES = %w[
    messages_settings messages_providers messages_notifications messages_logs
    messages_email_settings messages_twilio_settings messages_plivo_settings
    messages_textanywhere_settings
  ].freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  test "admin can view every messages page" do
    Message.create!(direction: "outgoing", channel: "email", audience: "customer",
                    to_address: "c@example.org", customer_id: users(:jx).id,
                    subject: "Hi", body: "Hi", status: "sent")
    Message.create!(direction: "incoming", channel: "twilio", from_address: "+447700900999",
                    body: "Who is this?", status: "received")
    login_admin
    (MESSAGES_PAGES + %w[unknown_inbox]).each do |page|
      get "/#{page}"
      assert_response :success, "expected 200 for admin on /#{page}"
    end
  end

  test "provider is forbidden from messages pages" do
    login_provider
    (MESSAGES_PAGES + %w[unknown_inbox]).each do |page|
      get "/#{page}"
      assert_response :forbidden, "expected 403 for provider on /#{page}"
    end
  end

  test "unauthenticated users are redirected to login" do
    get "/messages_settings"
    assert_redirected_to "/login"
  end

  test "the inbox lists each message as a block with the metadata line above the full text" do
    Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email, customer_id: users(:jx).id,
                    subject: "Re: Confirmed", body: "Line one\nLine two\n" + ("Long text " * 80), status: "received")
    login_admin
    %w[inbox unknown_inbox].each do |page|
      get "/#{page}"
      assert_select "##{page.dasherize}-page table", 0, "#{page}: no table"
    end
    get "/inbox"
    assert_select ".inbox-message.message-unread", 1 do
      assert_select ".inbox-meta a[href='/customers?customer_id=#{users(:jx).id}']", text: "JX"
      assert_select ".inbox-meta .tag", text: "Email"
      assert_select ".inbox-meta .tag", text: "Received"
      assert_select ".inbox-meta .mark-read"
      assert_select ".inbox-subject", text: "Re: Confirmed"
    end
    assert css_select(".inbox-message .inbox-body").sole.text.start_with?("Line one\nLine two\nLong text"), "line breaks are kept"
    assert_equal 80, css_select(".inbox-message .inbox-body").sole.text.scan("Long text").size, "the whole text is shown"
  end

  test "unknown inbox messages stay unread until marked read" do
    message = Message.create!(direction: "incoming", channel: "twilio", from_address: "+447700900999",
                              body: "Hello?", status: "received")
    login_admin
    get "/unknown_inbox"
    assert_response :success
    assert_equal 1, Message.unread.unknown_sender.count
    assert_includes response.body, "mark-read"

    post "/messages/#{message.id}/mark_read"
    assert_equal true, response.parsed_body["success"]
    assert_equal 0, Message.unread.unknown_sender.count
  end

  test "notification save and destroy round trip" do
    login_admin
    post "/messages_notifications/save", params: {
      notification: { title: "Test", event: "created", audiences: [ "customer" ],
                      channels: [ "email" ], short_text: "S", long_text: "L" }
    }
    assert_response :success
    id = JSON.parse(response.body)["id"]
    notification = Notification.find(id)
    assert_equal [ "customer" ], notification.audiences
    assert_equal [ "email" ], notification.channels

    post "/messages_notifications/save", params: {
      notification: { id: id, title: "Test 2", event: "coming_up", lead_mode: "day_at",
                      lead_days: 1, send_time: "09:00", audiences: [ "customer", "provider" ],
                      channels: [] }
    }
    assert_response :success
    assert_equal "Test 2", notification.reload.title
    assert_equal "day_at", notification.lead_mode

    post "/messages_notifications/destroy", params: { notification_id: id }
    assert_response :success
    assert_nil Notification.find_by(id: id)
  end
end

# The notification templates as Rails forms.
class MessagesNotificationsFormTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "panels render per notification, add opens a blank one, save and delete come back with the panel open" do
    login_admin
    existing = Notification.create!(title: "Reminder", event: "coming_up", lead_mode: "day_at", lead_days: 1, send_time: "09:00",
                                    audiences: [ "customer" ], channels: [ "email" ], short_text: "S", long_text: "L")
    get "/messages_notifications"
    assert_select "turbo-frame#notifications .notification-panel[data-id=?]", existing.id.to_s do
      assert_select ".notification-title-display", text: "Reminder"
      assert_select ".notification-body[style*='display:none']"
      assert_select "form.notification-form input[name='notification[id]'][value=?]", existing.id.to_s
      assert_select "select[name='notification[lead_mode]'] option[selected][value=day_at]"
      assert_select "select[name='notification[day_at_days]'] option[selected][value='1']"
      assert_select "input[name='notification[audiences][]'][value=customer][checked]"
      assert_select "form[action='/messages_notifications/destroy'] input[name=notification_id][value=?]", existing.id.to_s
    end
    assert_select "a#add-notification[href='/messages_notifications?new=1']"

    get "/messages_notifications", params: { new: 1 }
    assert_select ".notification-panel", count: 2
    assert_select ".notification-panel[data-id=''] .notification-body:not([style])"

    post "/messages_notifications/save", params: { form: "1", notification: { title: "New one", event: "created", audiences: [ "", "provider" ],
                                                                               channels: [ "" ], short_text: "S", long_text: "L" } }
    created = Notification.find_by!(title: "New one")
    assert_redirected_to "/messages_notifications?open=#{created.id}"
    follow_redirect!
    assert_select ".notice[data-tone=success]", text: I18n.t("ea.notification_saved")
    assert_select ".notification-panel[data-id=?] .notification-body:not([style])", created.id.to_s
    assert_equal [ "provider" ], created.audiences
    assert_equal [], created.channels

    post "/messages_notifications/save", params: { form: "1", notification: { id: existing.id, title: "Reminder", event: "coming_up",
                                                                               lead_mode: "day_at", day_at_days: "3", lead_days: "0", lead_hours: "5", send_time: "10:00" } }
    assert_equal [ 3, 0, "10:00" ], [ existing.reload.lead_days, existing.lead_hours, existing.send_time ]

    post "/messages_notifications/destroy", params: { form: "1", notification_id: created.id }
    assert_redirected_to "/messages_notifications"
    assert_nil Notification.find_by(id: created.id)
  end
end
