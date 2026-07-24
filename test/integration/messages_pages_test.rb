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

  test "visiting the unknown inbox clears unread unknown messages" do
    Message.create!(direction: "incoming", channel: "twilio", from_address: "+447700900999",
                    body: "Hello?", status: "received")
    assert_equal 1, Message.unread.unknown_sender.count
    login_admin
    get "/unknown_inbox"
    assert_response :success
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
