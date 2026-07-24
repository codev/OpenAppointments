require "test_helper"

class CustomerMessagesTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def customer = users(:jx)

  test "find returns customer messages and marks incoming read" do
    Message.create!(direction: "incoming", channel: "email", from_address: customer.email,
                    customer_id: customer.id, body: "Running late", status: "received")
    login_admin
    post "/customer_messages/find", params: { customer_id: customer.id }
    assert_response :success
    rows = JSON.parse(response.body)
    assert_equal 1, rows.size
    assert_equal "Running late", rows.first["body"]
    assert_equal "Email", rows.first["channel_label"]
    assert_equal 0, Message.unread.where(customer_id: customer.id).count
  end

  test "customer search rows include unread counts" do
    Message.create!(direction: "incoming", channel: "email", from_address: customer.email,
                    customer_id: customer.id, body: "Hello", status: "received")
    login_admin
    post "/customers/search", params: { keyword: "" }
    assert_response :success
    row = JSON.parse(response.body).find { |r| r["id"] == customer.id }
    assert_equal 1, row["unread_messages"]
  end

  test "manual send queues a signed email using the default subject" do
    login_admin
    assert_enqueued_jobs 1, only: MessageDeliveryJob do
      post "/customer_messages/send", params: { customer_id: customer.id, channel: "email", body: "See you soon" }
    end
    assert_response :success
    message = Message.outgoing.newest_first.first
    assert_equal customer.email, message.to_address
    assert_includes message.body, "See you soon"
    assert_match(/\n\n- .+ - /, message.body)
    assert_includes message.subject, "Appointments"
  end

  test "send to all providers uses every enabled channel with an address" do
    Setting.set("messages_twilio_enabled", "1")
    Setting.set("messages_twilio_account_sid", "AC123")
    Setting.set("messages_twilio_auth_token", "token")
    Setting.set("messages_twilio_from", "+15005550006")
    customer.update!(phone_number: "+447700900123")

    login_admin
    post "/customer_messages/send", params: { customer_id: customer.id, channel: "all", body: "Hi" }
    assert_response :success
    assert_equal %w[email twilio], JSON.parse(response.body)["messages"].map { |m| m["channel"] }.sort
  ensure
    Setting.set("messages_twilio_enabled", "0")
  end

  test "send with no channel selected fails" do
    login_admin
    post "/customer_messages/send", params: { customer_id: customer.id, channel: "", body: "Hi" }
    assert_response :success
    assert_equal false, JSON.parse(response.body)["success"]
  end
end
