require "test_helper"

class InboundMessagesTest < ActionDispatch::IntegrationTest
  setup do
    Setting.set("messages_inbound_token", "secrettoken123")
    Setting.set("messages_twilio_enabled", "1")
    Setting.set("messages_twilio_incoming", "1")
    Setting.set("messages_twilio_account_sid", "AC1")
    Setting.set("messages_twilio_auth_token", "authtoken")
    Setting.set("messages_twilio_from", "+15005550006")
  end

  teardown do
    Setting.set("messages_twilio_enabled", "0")
    Setting.set("messages_twilio_incoming", "0")
  end

  def twilio_signature(url, params)
    data = url + params.sort.map { |key, value| "#{key}#{value}" }.join
    Base64.strict_encode64(OpenSSL::HMAC.digest("sha1", "authtoken", data))
  end

  test "twilio webhook stores an incoming message for a known customer" do
    params = { "From" => users(:jx).phone_number, "To" => "+15005550006", "Body" => "On my way" }
    url = "http://www.example.com/messages/inbound/twilio/secrettoken123"
    post "/messages/inbound/twilio/secrettoken123", params: params,
         headers: { "X-Twilio-Signature" => twilio_signature(url, params) }
    assert_response :success
    message = Message.incoming.sole
    assert_equal users(:jx).id, message.customer_id
    assert_equal "On my way", message.body
    assert_equal "twilio", message.channel
  end

  test "an SMS in E.164 matches a customer whose number was typed in UK local format" do
    users(:jx).update!(phone_number: "07700 900123")
    params = { "From" => "+447700900123", "To" => "+15005550006", "Body" => "Running late" }
    url = "http://www.example.com/messages/inbound/twilio/secrettoken123"
    post "/messages/inbound/twilio/secrettoken123", params: params,
         headers: { "X-Twilio-Signature" => twilio_signature(url, params) }
    assert_response :success
    assert_equal users(:jx).id, Message.incoming.sole.customer_id
  end

  test "an SMS from a customer fires the customer message notification" do
    Notification.create!(title: "Customer Message Received", event: "customer_message", audiences: %w[provider],
                         channels: %w[email], short_text: "New message from {{Customer Name}}")
    Appointment.create!(start_datetime: 2.days.from_now, end_datetime: 2.days.from_now + 30.minutes,
                        provider: users(:zane), customer: users(:jx), service: services(:haircut), status: "Booked")
    params = { "From" => users(:jx).phone_number, "To" => "+15005550006", "Body" => "On my way" }
    url = "http://www.example.com/messages/inbound/twilio/secrettoken123"
    post "/messages/inbound/twilio/secrettoken123", params: params,
         headers: { "X-Twilio-Signature" => twilio_signature(url, params) }
    assert_response :success
    assert_equal [ users(:zane).email ], Message.outgoing.pluck(:to_address)
  end

  test "twilio webhook rejects a bad signature" do
    post "/messages/inbound/twilio/secrettoken123",
         params: { "From" => "+447700900321", "Body" => "spoof" },
         headers: { "X-Twilio-Signature" => "bogus" }
    assert_response :forbidden
    assert_equal 0, Message.count
  end

  test "wrong token is not found" do
    post "/messages/inbound/twilio/wrongtoken", params: { "From" => "+447700900321", "Body" => "x" }
    assert_response :not_found
  end

  test "disabled channel is not found" do
    Setting.set("messages_twilio_incoming", "0")
    params = { "From" => "+447700900321", "Body" => "x" }
    url = "http://www.example.com/messages/inbound/twilio/secrettoken123"
    post "/messages/inbound/twilio/secrettoken123", params: params,
         headers: { "X-Twilio-Signature" => twilio_signature(url, params) }
    assert_response :not_found
  end

  test "plivo webhook stores unknown senders in the unknown inbox" do
    Setting.set("messages_plivo_enabled", "1")
    Setting.set("messages_plivo_incoming", "1")
    Setting.set("messages_plivo_auth_id", "MA1")
    Setting.set("messages_plivo_auth_token", "t")
    Setting.set("messages_plivo_from", "+15005550006")

    post "/messages/inbound/plivo/secrettoken123",
         params: { "From" => "+447700900999", "To" => "+15005550006", "Text" => "Who dis" }
    assert_response :success
    message = Message.incoming.sole
    assert_nil message.customer_id
    assert_equal "Who dis", message.body
  ensure
    Setting.set("messages_plivo_enabled", "0")
    Setting.set("messages_plivo_incoming", "0")
  end
end
