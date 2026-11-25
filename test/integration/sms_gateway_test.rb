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

  test "deliver keeps the gateway's message id so delivery reports find the row" do
    enable_gateway
    stub_request(:post, "#{BASE}/api/3rdparty/v1/message")
      .to_return(status: 201, body: { id: "zXDYfTmTVf3iMd16zzdBj", state: "Pending" }.to_json)
    message = Message.create!(direction: "outgoing", channel: "smsgateway", status: "queued",
                              to_address: "+447912345678", body: "x")
    Messaging::SmsGateway.deliver(message)
    assert_equal "zXDYfTmTVf3iMd16zzdBj", message.reload.provider_message_id
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
    { settings: { messages_smsgateway_enabled: enabled, messages_smsgateway_incoming: incoming,
                  messages_smsgateway_url: BASE, messages_smsgateway_login: "NAWFKJ",
                  messages_smsgateway_password: "secretpw" } }
  end

  # The settings form redirects back with a flash; read it from the page, which
  # reads the phone status from the server while the gateway is active.
  def assert_saved
    stub_request(:get, "#{BASE}/api/3rdparty/v1/messages?state=Pending").to_return(status: 200, body: "[]")
    assert_redirected_to "/messages_smsgateway_settings"
    follow_redirect!
    assert_select ".alert-success"
  end

  def assert_save_failed(pattern)
    assert_redirected_to "/messages_smsgateway_settings"
    follow_redirect!
    assert_select ".alert-danger", text: pattern
  end

  test "activating save validates credentials, registers the webhook once and dedupes" do
    login_admin
    Setting.set("messages_inbound_token", "secrettoken123")
    token = Setting.get("messages_inbound_token")
    inbound = %r{/messages/inbound/smsgateway/#{token}}

    # Bad credentials block the save.
    stub_request(:get, "#{BASE}/api/3rdparty/v1/device").to_return(status: 401)
    post "/messages_smsgateway_settings/save", params: save_params
    assert_save_failed(/wrong API login or password/)
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
    assert_saved
    assert_equal "1", Setting.get("messages_smsgateway_enabled")
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/dup1")
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/dup2")
    # One registration per event: replies, and the phone's delivery and failure reports.
    %w[sms:received sms:delivered sms:failed].each do |event|
      assert_requested(:post, "#{BASE}/api/3rdparty/v1/webhooks") do |req|
        body = JSON.parse(req.body)
        body["url"].match?(inbound) && body["event"] == event
      end
    end
  end

  test "turning incoming off deregisters the replies webhook and keeps the delivery reports" do
    enable_gateway
    login_admin
    stub_request(:get, "#{BASE}/api/3rdparty/v1/device").to_return(status: 200, body: "[]")
    url = "https://a.example.org/messages/inbound/smsgateway/tok"
    stub_request(:get, "#{BASE}/api/3rdparty/v1/webhooks").to_return(
      status: 200,
      body: [ { id: "w1", url: url, event: "sms:received" }, { id: "w2", url: url, event: "sms:delivered" },
              { id: "w3", url: url, event: "sms:failed" } ].to_json
    )
    stub_request(:delete, %r{#{BASE}/api/3rdparty/v1/webhooks/w\d}).to_return(status: 204)
    stub_request(:post, "#{BASE}/api/3rdparty/v1/webhooks").to_return(status: 201, body: "{}")

    post "/messages_smsgateway_settings/save", params: save_params(incoming: "0")
    assert_saved
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/w1")
    # The stale registrations (another host) go and the two reports are registered afresh.
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/w2")
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/w3")
    assert_requested(:post, "#{BASE}/api/3rdparty/v1/webhooks", times: 2)
    assert_not_requested(:post, "#{BASE}/api/3rdparty/v1/webhooks") { |req| JSON.parse(req.body)["event"] == "sms:received" }
  end

  test "deactivating the gateway deregisters every webhook of ours" do
    enable_gateway
    login_admin
    url = "https://a.example.org/messages/inbound/smsgateway/tok"
    stub_request(:get, "#{BASE}/api/3rdparty/v1/webhooks").to_return(
      status: 200, body: [ { id: "w1", url: url, event: "sms:received" }, { id: "w2", url: url, event: "sms:delivered" } ].to_json
    )
    stub_request(:delete, %r{#{BASE}/api/3rdparty/v1/webhooks/w\d}).to_return(status: 204)

    post "/messages_smsgateway_settings/save", params: save_params(enabled: "0", incoming: "0")
    assert_saved
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/w1")
    assert_requested(:delete, "#{BASE}/api/3rdparty/v1/webhooks/w2")
  end

  test "test sms sends through the gateway and logs the message" do
    enable_gateway
    login_admin
    stub_request(:post, "#{BASE}/api/3rdparty/v1/message").to_return(status: 201, body: "{}")

    post "/messages_smsgateway_settings/test_send", params: { address: "07971 862965" }
    assert_equal true, response.parsed_body["success"]
    message = Message.order(id: :desc).first
    assert_equal "sent", message.status
    assert_equal "+447971862965", message.to_address

    stub_request(:post, "#{BASE}/api/3rdparty/v1/message").to_return(status: 400, body: { message: "invalid phone number" }.to_json)
    post "/messages_smsgateway_settings/test_send", params: { address: "07971862965" }
    assert_equal false, response.parsed_body["success"]
    assert_match(/invalid phone number/, response.parsed_body["message"])
    assert_equal "failed", Message.order(id: :desc).first.status
  end

  test "country restriction blocks foreign numbers when enabled" do
    enable_gateway
    login_admin
    Setting.set("messages_smsgateway_default_country_only", "1")

    post "/messages_smsgateway_settings/test_send", params: { address: "+15551234567" }
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

  def report_payload(event, message_id: "gw1", reason: nil)
    payload = { messageId: message_id, sender: "+447700111222", recipient: "+447912345678", simNumber: 1 }
    payload[:deliveredAt] = "2026-11-25T13:42:10.000+00:00" if event == "sms:delivered"
    payload.merge!(failedAt: "2026-11-25T13:42:10.000+00:00", reason: reason) if event == "sms:failed"
    { deviceId: "dev1", event: event, id: "evt-#{event}", payload: payload }.to_json
  end

  def sent_text(provider_message_id: "gw1")
    Message.create!(direction: "outgoing", channel: "smsgateway", status: "sent", to_address: "+447912345678",
                    customer: users(:jx), subject: "Your appointment is confirmed", body: "Booked.",
                    provider_message_id: provider_message_id)
  end

  test "a delivery report marks the text delivered" do
    enable_gateway
    Setting.set("messages_smsgateway_signing_key", "sekrit")
    message = sent_text
    body = report_payload("sms:delivered")
    assert_no_difference "Message.count" do
      post "/messages/inbound/smsgateway/#{Setting.get('messages_inbound_token')}", params: body,
           headers: signed_headers(body, "sekrit")
    end
    assert_response :success
    assert_equal "delivered", message.reload.status
  end

  test "a failure report marks the text failed with the phone's reason and shows on the Activity page" do
    enable_gateway
    message = sent_text
    body = report_payload("sms:failed", reason: "RESULT_ERROR_GENERIC_FAILURE (Generic failure cause)")
    assert_difference -> { ActivityEvent.where(kind: "message_failed").count }, 1 do
      post "/messages/inbound/smsgateway/#{Setting.get('messages_inbound_token')}", params: body,
           headers: { "Content-Type" => "application/json" }
    end
    assert_response :success
    message.reload
    assert_equal "failed", message.status
    assert_match(/Generic failure cause/, message.error)
    assert_equal message.id, ActivityEvent.where(kind: "message_failed").last.message_id
  end

  test "a report for an unknown message, or an older state, changes nothing" do
    enable_gateway
    token = Setting.get("messages_inbound_token")
    message = sent_text
    message.update!(status: "delivered")

    post "/messages/inbound/smsgateway/#{token}", params: report_payload("sms:delivered", message_id: "nope"),
         headers: { "Content-Type" => "application/json" }
    assert_response :success

    # A sent report after delivery would be a replay of an older event.
    post "/messages/inbound/smsgateway/#{token}", params: report_payload("sms:sent"),
         headers: { "Content-Type" => "application/json" }
    assert_response :success
    assert_equal "delivered", message.reload.status
  end

  test "delivery reports arrive even with replies off, but need the signature and an active gateway" do
    enable_gateway
    Setting.set("messages_smsgateway_incoming", "0")
    Setting.set("messages_smsgateway_signing_key", "sekrit")
    token = Setting.get("messages_inbound_token")
    message = sent_text
    body = report_payload("sms:delivered")

    post "/messages/inbound/smsgateway/#{token}", params: body, headers: signed_headers(body, "wrong")
    assert_response :forbidden
    assert_equal "sent", message.reload.status

    post "/messages/inbound/smsgateway/#{token}", params: body, headers: signed_headers(body, "sekrit")
    assert_response :success
    assert_equal "delivered", message.reload.status

    Setting.set("messages_smsgateway_enabled", "0")
    post "/messages/inbound/smsgateway/#{token}", params: body, headers: signed_headers(body, "sekrit")
    assert_response :not_found
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

    post "/messages_smsgateway_settings/save", params: { settings: { messages_smsgateway_url: BASE } }
    assert_saved
    assert_equal BASE, Setting.get("messages_smsgateway_url"),
                 "inactive saves persist without server validation"
  end

  test "the settings page reports when the phone last checked in and how many texts wait for it" do
    enable_gateway
    login_admin
    stub_request(:get, "#{BASE}/api/3rdparty/v1/device")
      .to_return(status: 200, body: [ { id: "d1", name: "samsung", lastSeen: 70.seconds.ago.utc.iso8601 } ].to_json)
    stub_request(:get, "#{BASE}/api/3rdparty/v1/messages?state=Pending")
      .to_return(status: 200, body: [ { id: "a" }, { id: "b" } ].to_json)

    get "/messages_smsgateway_settings"
    assert_response :success
    assert_select "#smsgateway-phone-status[data-stale=false]"
    assert_select "#smsgateway-phone-status [data-field=last_seen]", text: /1 minute/
    assert_select "#smsgateway-phone-status [data-field=waiting]", text: /2/
    assert_select "#smsgateway-phone-status .alert-warning", count: 0
  end

  test "the settings page warns when the phone has not checked in for five minutes" do
    enable_gateway
    login_admin
    stub_request(:get, "#{BASE}/api/3rdparty/v1/device")
      .to_return(status: 200, body: [ { id: "d1", lastSeen: 20.minutes.ago.utc.iso8601 } ].to_json)
    stub_request(:get, "#{BASE}/api/3rdparty/v1/messages?state=Pending")
      .to_return(status: 200, body: [ { id: "a" } ].to_json)

    get "/messages_smsgateway_settings"
    assert_select "#smsgateway-phone-status[data-stale=true] .alert-warning"
    assert_select "#smsgateway-phone-status [data-field=last_seen]", text: /20 minutes/
  end

  test "the settings page says when the gateway server cannot be reached, and shows nothing when inactive" do
    enable_gateway
    login_admin
    stub_request(:get, "#{BASE}/api/3rdparty/v1/device").to_return(status: 503, body: "down")

    get "/messages_smsgateway_settings"
    assert_select "#smsgateway-phone-status .alert-danger", text: /503/

    Setting.set("messages_smsgateway_enabled", "0")
    get "/messages_smsgateway_settings"
    assert_select "#smsgateway-phone-status", count: 0
  end

  test "the gateway strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[messages_smsgateway_url messages_smsgateway_login messages_smsgateway_password
         messages_smsgateway_signing_key messages_provider_smsgateway_info
         default_country_code default_country_code_hint messages_default_country_only
         messages_smsgateway_setup messages_smsgateway_apk messages_smsgateway_apk_link
         messages_smsgateway_step_device messages_smsgateway_step_server
         messages_smsgateway_step_server_public messages_smsgateway_step_server_or
         messages_smsgateway_step_server_private
         messages_smsgateway_step_url messages_smsgateway_step_token
         messages_smsgateway_step_signing messages_smsgateway_step_credentials
         messages_smsgateway_step_activate messages_smsgateway_inbound_hint
         messages_smsgateway_invalid messages_test_sms_number
         messages_status_delivered messages_smsgateway_phone messages_smsgateway_phone_last_seen
         messages_smsgateway_phone_waiting messages_smsgateway_phone_stale
         messages_smsgateway_phone_unreachable messages_smsgateway_phone_failed].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
