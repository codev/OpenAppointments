require "test_helper"
require "webmock/minitest"

class SmsGatewayTest < ActionDispatch::IntegrationTest
  BASE = "https://sms.example.org".freeze

  def enable_gateway
    Setting.set("messages_inbound_token", "secrettoken123")
    Setting.set("messages_smsgateway_enabled", "1")
    Setting.set("messages_smsgateway_incoming", "1")
    Setting.set("messages_smsgateway_url", "#{BASE}/")
    Setting.set("messages_smsgateway_login", "NAWFKJ")
    Setting.set("messages_smsgateway_password", "secretpw")
  end

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "channel registry lists the gateway when configured" do
    assert_not Messaging.enabled_channel_keys.include?("smsgateway")
    enable_gateway
    assert_includes Messaging.enabled_channel_keys, "smsgateway"
    assert_includes Messaging.incoming_channels.map(&:key), "smsgateway"
  end

  test "deliver posts the message to the third party API with basic auth" do
    enable_gateway
    stub_request(:post, "#{BASE}/api/3rdparty/v1/message")
      .to_return(status: 201, body: { id: "abc", state: "Pending" }.to_json)

    message = Message.create!(direction: "outgoing", channel: "smsgateway", status: "queued",
                              to_address: "+447912345678", body: "Reminder: Thursday 11:30")
    Messaging::SmsGateway.deliver(message)

    assert_requested(:post, "#{BASE}/api/3rdparty/v1/message") do |req|
      body = JSON.parse(req.body)
      req.headers["Authorization"] == "Basic #{Base64.strict_encode64('NAWFKJ:secretpw')}" &&
        body["message"] == "Reminder: Thursday 11:30" &&
        body["phoneNumbers"] == [ "+447912345678" ]
    end
  end

  test "deliver raises on API errors" do
    enable_gateway
    stub_request(:post, "#{BASE}/api/3rdparty/v1/message")
      .to_return(status: 400, body: { message: "invalid phone number" }.to_json)
    message = Message.create!(direction: "outgoing", channel: "smsgateway", status: "queued",
                              to_address: "12", body: "x")
    error = assert_raises(RuntimeError) { Messaging::SmsGateway.deliver(message) }
    assert_match(/SMS Gateway 400/, error.message)
  end

  test "register webhook endpoint posts the inbound URL" do
    enable_gateway
    login_admin
    stub_request(:post, "#{BASE}/api/3rdparty/v1/webhooks").to_return(status: 201, body: "{}")

    post "/messages_smsgateway_settings/register_webhook"
    assert_response :success
    assert_equal true, response.parsed_body["success"]

    token = Setting.get("messages_inbound_token")
    assert_requested(:post, "#{BASE}/api/3rdparty/v1/webhooks") do |req|
      body = JSON.parse(req.body)
      body["event"] == "sms:received" && body["url"].include?("/messages/inbound/smsgateway/#{token}")
    end
  end

  def webhook_payload(sender: "+447912345678", message: "Yes please")
    {
      deviceId: "dev1", event: "sms:received", id: "evt1",
      payload: { messageId: "m1", message: message, sender: sender,
                 recipient: "+447700111222", receivedAt: "2026-07-31T18:00:00.000+01:00" }
    }.to_json
  end

  def signed_headers(body, key, timestamp: Time.now.to_i.to_s)
    signature = OpenSSL::HMAC.hexdigest("sha256", key, body + timestamp)
    { "Content-Type" => "application/json", "X-Signature" => signature, "X-Timestamp" => timestamp }
  end

  test "inbound webhook creates an incoming message matched by phone" do
    enable_gateway
    Setting.set("messages_smsgateway_signing_key", "sekrit")
    customer = users(:jx)
    customer.update!(phone_number: "+447912345678")
    token = Setting.get("messages_inbound_token")

    body = webhook_payload
    assert_difference "Message.incoming.count", 1 do
      post "/messages/inbound/smsgateway/#{token}", params: body,
           headers: signed_headers(body, "sekrit")
    end
    assert_response :success
    message = Message.incoming.order(id: :desc).first
    assert_equal "smsgateway", message.channel
    assert_equal "+447912345678", message.from_address
    assert_equal customer.id, message.customer_id
    assert_equal "Yes please", message.body
  end

  test "inbound webhook normalises a plus-less sender" do
    enable_gateway
    token = Setting.get("messages_inbound_token")
    body = webhook_payload(sender: "447912345678")
    post "/messages/inbound/smsgateway/#{token}", params: body,
         headers: { "Content-Type" => "application/json" }
    assert_response :success
    assert_equal "+447912345678", Message.incoming.order(id: :desc).first.from_address
  end

  test "inbound webhook rejects bad signatures when a signing key is set" do
    enable_gateway
    Setting.set("messages_smsgateway_signing_key", "sekrit")
    token = Setting.get("messages_inbound_token")

    body = webhook_payload
    assert_no_difference "Message.count" do
      post "/messages/inbound/smsgateway/#{token}", params: body,
           headers: signed_headers(body, "wrong-key")
    end
    assert_response :forbidden

    assert_no_difference "Message.count" do
      post "/messages/inbound/smsgateway/#{token}", params: body,
           headers: { "Content-Type" => "application/json" }
    end
    assert_response :forbidden
  end

  test "inbound webhook rejects a bad token and a disabled channel" do
    enable_gateway
    body = webhook_payload
    post "/messages/inbound/smsgateway/wrong-token", params: body,
         headers: { "Content-Type" => "application/json" }
    assert_response :not_found

    Setting.set("messages_smsgateway_enabled", "0")
    post "/messages/inbound/smsgateway/#{Setting.get('messages_inbound_token')}", params: body,
         headers: { "Content-Type" => "application/json" }
    assert_response :not_found
  end

  test "settings page renders and saves the gateway settings" do
    login_admin
    get "/messages_smsgateway_settings"
    assert_response :success
    assert_select "[data-field=messages_smsgateway_url]"
    assert_select "#register-webhook"

    post "/messages_smsgateway_settings/save", params: {
      provider_settings: [
        { name: "messages_smsgateway_enabled", value: "1" },
        { name: "messages_smsgateway_url", value: BASE },
        { name: "messages_smsgateway_login", value: "AB" },
        { name: "messages_smsgateway_password", value: "pw" }
      ]
    }
    assert_response :success
    assert_equal BASE, Setting.get("messages_smsgateway_url")
  end
end
