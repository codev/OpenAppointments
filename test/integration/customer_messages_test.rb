require "test_helper"

class CustomerMessagesTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def customer = users(:jx)

  test "find returns customer messages without marking them read" do
    Message.create!(direction: "incoming", channel: "email", from_address: customer.email,
                    customer_id: customer.id, body: "Running late", status: "received")
    login_admin
    post "/customer_messages/find", params: { customer_id: customer.id }
    assert_response :success
    rows = response.parsed_body["messages"]
    assert_equal 1, rows.size
    assert_equal "Running late", rows.first["body"]
    assert_equal "Email", rows.first["channel_label"]
    assert_equal false, rows.first["read"]
    assert_equal false, response.parsed_body["more"]
    assert_equal 1, Message.unread.where(customer_id: customer.id).count

    post "/customer_messages/mark_read", params: { customer_id: customer.id }
    assert_equal 0, response.parsed_body["inbox_unread"]
    assert_equal 0, Message.unread.where(customer_id: customer.id).count
  end

  def incoming(body, at)
    Message.create!(direction: "incoming", channel: "email", from_address: customer.email,
                    customer_id: customer.id, body: body, status: "received", created_at: at)
  end

  test "find opens on the messages since the most recent appointment, oldest first, and says if older ones exist" do
    Appointment.where(id_users_customer: customer.id).delete_all
    Appointment.create!(customer: customer, provider: users(:zane), service: services(:haircut),
                        start_datetime: 2.days.ago, end_datetime: 2.days.ago + 30.minutes, is_unavailability: false)
    incoming("Before the appointment", 3.days.ago)
    incoming("After, first", 1.day.ago)
    incoming("After, second", 1.hour.ago)
    login_admin
    post "/customer_messages/find", params: { customer_id: customer.id }
    assert_equal [ "After, first", "After, second" ], response.parsed_body["messages"].map { |row| row["body"] }
    assert_equal true, response.parsed_body["more"]
  end

  test "find falls back to the latest twenty when no messages follow the appointment or there is none" do
    Appointment.where(id_users_customer: customer.id).delete_all
    25.times { |i| incoming("Message #{i}", (30 - i).days.ago) }
    login_admin
    post "/customer_messages/find", params: { customer_id: customer.id }
    rows = response.parsed_body["messages"]
    assert_equal 20, rows.size
    assert_equal "Message 5", rows.first["body"]
    assert_equal "Message 24", rows.last["body"]
    assert_equal true, response.parsed_body["more"]

    Appointment.create!(customer: customer, provider: users(:zane), service: services(:haircut),
                        start_datetime: 1.day.ago, end_datetime: 1.day.ago + 30.minutes, is_unavailability: false)
    post "/customer_messages/find", params: { customer_id: customer.id }
    assert_equal 20, response.parsed_body["messages"].size
  end

  test "find with before_id pages twenty older messages and says when none are left" do
    Appointment.where(id_users_customer: customer.id).delete_all
    25.times { |i| incoming("Message #{i}", (30 - i).days.ago) }
    oldest_shown = Message.where(customer_id: customer.id, body: "Message 5").first
    login_admin
    post "/customer_messages/find", params: { customer_id: customer.id, before_id: oldest_shown.id }
    rows = response.parsed_body["messages"]
    assert_equal [ "Message 0", "Message 1", "Message 2", "Message 3", "Message 4" ], rows.map { |row| row["body"] }
    assert_equal false, response.parsed_body["more"]
  end

  test "find gives the time in the settings date style, with the year only when it is not this year" do
    incoming("This year", Time.current.change(month: 3, day: 7, hour: 14, min: 2))
    incoming("Last year", (Time.current - 1.year).change(month: 11, day: 30, hour: 9, min: 5))
    login_admin
    post "/customer_messages/find", params: { customer_id: customer.id }
    times = response.parsed_body["messages"].to_h { |row| [ row["body"], row["created_at"] ] }
    assert_equal "07/03 2:02 pm", times["This year"]
    assert_equal "30/11/#{Time.current.year - 1} 9:05 am", times["Last year"]

    Setting.set("date_display", "month_short")
    Setting.set("time_format", "military")
    post "/customer_messages/find", params: { customer_id: customer.id }
    times = response.parsed_body["messages"].to_h { |row| [ row["body"], row["created_at"] ] }
    assert_equal "7 Mar 14:02", times["This year"]
    assert_equal "30 Nov #{Time.current.year - 1} 09:05", times["Last year"]
  end

  test "inbox lists messages the user may see with an unread badge in the header" do
    message = Message.create!(direction: "incoming", channel: "email", from_address: customer.email,
                              customer_id: customer.id, body: "Running late", status: "received")
    login_admin
    get "/inbox"
    assert_response :success
    assert_includes response.body, "Running late"
    assert_includes response.body, 'id="inbox-unread" class="badge bg-danger ms-1 ">1<'

    post "/messages/#{message.id}/mark_read"
    assert_equal 0, response.parsed_body["inbox_unread"]
    get "/inbox?unread=1"
    assert_not_includes response.body, "Running late"
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
