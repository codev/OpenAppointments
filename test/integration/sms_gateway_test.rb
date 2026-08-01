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

  def save_params(enabled: "1", incoming: "1")
    { provider_settings: [
      { name: "messages_smsgateway_enabled", value: enabled },
      { name: "messages_smsgateway_incoming", value: incoming },
      { name: "messages_smsgateway_url", value: BASE },
      { name: "messages_smsgateway_login", value: "NAWFKJ" },
      { name: "messages_smsgateway_password", value: "secretpw" }
    ] }
  end

  test "activating save validates credentials, registers the webhook once and dedupes" do
    login_admin
    Setting.set("messages_inbound_token", "secrettoken123")
    token = Setting.get("messages_inbound_token")
    inbound = %r{/messages/inbound/smsgateway/#{token}}

    # Bad credentials block the save.
    stub_request(:get, "#{BASE}/api/3rdparty/v1/device").to_return(status: 401)
    post "/messages_smsgateway_settings/save", params: save_params
    assert_equal false, response.parsed_body["success"]
    assert_match(/wrong API login or password/, response.parsed_body["message"])
    assert_not_equal "1", Setting.get("messages_smsgateway_enabled")

    # Good credentials: stale duplicates are removed, the URL registered once.
    stub_request(:get, "#{BASE}/api/3rdparty/v1/device").to_return(status: 200, body: "[]")
    stub_request(:get, "#{BASE}/api/3rdparty/v1/webhooks").to_return(
      status: 200,
      body: [
        { id: "dup1", url: "https://appointments.example.org/messages/inbound/smsgateway/oldtoken", event: "sms:received" },
        { id: "dup2", url: "https://appointments.example.org/messages/inbound/smsgateway/oldtoken", event: "sms:received" },
        { id: "other", url: "https://elsewhere.example.org/unrelated", event: "sms:received" }
      ].to_json
    )
    stub_request(:delete, %r{#{BASE}/api/3rdparty/v1/webhooks/dup[12]}).to_return(status: 204)
    stub_request(:post, "#{BASE}/api/3rdparty/v1/webhooks").to_return(status: 201, body: "{}")

    post "/messages_smsgateway_settings/save", params: save_params
    assert_equal true, response.parsed_body["success"]
    assert_equal "1", Setting.get("messages_smsgateway_enabled")
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/dup1")
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/dup2")
    assert_requested(:post, "#{BASE}/api/3rdparty/v1/webhooks") do |req|
      JSON.parse(req.body)["url"].match?(inbound)
    end
  end

  test "turning incoming off deregisters our webhooks" do
    enable_gateway
    login_admin
    stub_request(:get, "#{BASE}/api/3rdparty/v1/device").to_return(status: 200, body: "[]")
    stub_request(:get, "#{BASE}/api/3rdparty/v1/webhooks").to_return(
      status: 200,
      body: [ { id: "w1", url: "https://a.example.org/messages/inbound/smsgateway/tok", event: "sms:received" } ].to_json
    )
    stub_request(:delete, "#{BASE}/api/3rdparty/v1/webhooks/w1").to_return(status: 204)

    post "/messages_smsgateway_settings/save", params: save_params(incoming: "0")
    assert_equal true, response.parsed_body["success"]
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/w1")
  end

  test "test sms sends through the gateway and logs the message" do
    enable_gateway
    login_admin
    stub_request(:post, "#{BASE}/api/3rdparty/v1/message").to_return(status: 201, body: "{}")

    post "/messages_smsgateway_settings/test_sms", params: { number: "07971 862965" }
    assert_equal true, response.parsed_body["success"]
    message = Message.order(id: :desc).first
    assert_equal "sent", message.status
    assert_equal "+447971862965", message.to_address

    stub_request(:post, "#{BASE}/api/3rdparty/v1/message").to_return(status: 400, body: { message: "invalid phone number" }.to_json)
    post "/messages_smsgateway_settings/test_sms", params: { number: "07971862965" }
    assert_equal false, response.parsed_body["success"]
    assert_match(/invalid phone number/, response.parsed_body["message"])
    assert_equal "failed", Message.order(id: :desc).first.status
  end

  test "country restriction blocks foreign numbers when enabled" do
    enable_gateway
    login_admin
    Setting.set("messages_smsgateway_default_country_only", "1")

    post "/messages_smsgateway_settings/test_sms", params: { number: "+15551234567" }
    assert_equal false, response.parsed_body["success"]
    assert_match(/outside the default country/, response.parsed_body["message"])

    message = Message.create!(direction: "outgoing", channel: "smsgateway", status: "queued",
                              to_address: "+15551234567", body: "x")
    MessageDeliveryJob.perform_now(message.id)
    assert_equal "failed", message.reload.status
    assert_match(/outside the default country/, message.error)
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
    assert_select "#register-webhook", count: 0
    assert_select "#smsgateway-send-test"
    assert_select "a[href='https://github.com/capcom6/android-sms-gateway/releases']"

    post "/messages_smsgateway_settings/save", params: {
      provider_settings: [ { name: "messages_smsgateway_url", value: BASE } ]
    }
    assert_response :success
    assert_equal BASE, Setting.get("messages_smsgateway_url"),
                 "inactive saves persist without server validation"
  end

  test "the gateway strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[messages_smsgateway_url messages_smsgateway_login messages_smsgateway_password
         messages_smsgateway_signing_key messages_provider_smsgateway_info
         default_country_code default_country_code_hint messages_default_country_only
         messages_smsgateway_setup messages_smsgateway_apk messages_smsgateway_apk_link
         messages_smsgateway_step_device messages_smsgateway_step_url messages_smsgateway_step_token
         messages_smsgateway_step_signing messages_smsgateway_step_credentials
         messages_smsgateway_step_activate messages_smsgateway_inbound_hint
         messages_smsgateway_invalid messages_test_sms messages_test_sms_number
         messages_test_sms_sent].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
