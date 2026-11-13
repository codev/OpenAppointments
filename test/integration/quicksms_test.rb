require "test_helper"
require "webmock/minitest"

# QuickSMS (quicksms.com): Messaging API sends with a Bearer key, inbound V2
# webhooks signed with a per-number secret over "timestamp.body".
class QuicksmsTest < ActionDispatch::IntegrationTest
  SEND = "https://api.quicksms.com/v1/messages".freeze

  def enable_quicksms(incoming: "0", secret: "")
    Setting.set("messages_inbound_token", "secrettoken123")
    Setting.set("messages_quicksms_enabled", "1")
    Setting.set("messages_quicksms_incoming", incoming)
    Setting.set("messages_quicksms_api_key", "sk_test_abc")
    Setting.set("messages_quicksms_from", "OpenOut")
    Setting.set("messages_quicksms_signing_secret", secret)
  end

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def accepted(rejected: 0, error: nil)
    { sandbox: true, total: 1, accepted: 1 - rejected, rejected: rejected,
      messages: [ { quicksms_id: "q1", mobile_number: "447912345678", status: rejected.zero? ? "ACCEPTED" : "REJECTED",
                    error: error }.compact ] }.to_json
  end

  test "the registry lists QuickSMS once the key is set, with its defaults and colour" do
    assert_not Messaging.enabled_channel_keys.include?("quicksms")
    enable_quicksms(incoming: "1")
    assert_includes Messaging.enabled_channel_keys, "quicksms"
    assert_includes Messaging.incoming_channels.map(&:key), "quicksms"
    assert_equal "QuickSMS", Messaging::Quicksms.label
    assert_equal "0", Messaging::Defaults::SETTINGS["messages_quicksms_enabled"]
    assert_includes SettingsPage::SENSITIVE_SETTING_NAMES, "messages_quicksms_api_key"
    assert_includes SettingsPage::SENSITIVE_SETTING_NAMES, "messages_quicksms_signing_secret"
    assert_match(/"quicksms": \(/, Rails.root.join("app/assets/stylesheets/ea/backend.scss").read)
  end

  test "deliver posts the message with a Bearer key, digits-only number and the sender" do
    enable_quicksms
    stub_request(:post, SEND).to_return(status: 202, body: accepted)
    message = Message.create!(direction: "outgoing", channel: "quicksms", status: "queued",
                              to_address: "+447912345678", body: "Reminder: Thursday 11:30")
    Messaging::Quicksms.deliver(message)

    assert_requested(:post, SEND) do |req|
      body = JSON.parse(req.body)
      req.headers["Authorization"] == "Bearer sk_test_abc" && req.headers["Content-Type"] == "application/json" &&
        body == { "mobile_number" => "447912345678", "msg" => "Reminder: Thursday 11:30", "sender" => "OpenOut" }
    end
  end

  test "a 202 with a rejected recipient and a non-2xx both fail the delivery with the provider's words" do
    enable_quicksms
    stub_request(:post, SEND).to_return(status: 202, body: accepted(rejected: 1, error: { code: "SENDER_NOT_REGISTERED", message: "Sender not registered" }))
    message = Message.create!(direction: "outgoing", channel: "quicksms", status: "queued", to_address: "+447912345678", body: "x")
    error = assert_raises(RuntimeError) { Messaging::Quicksms.deliver(message) }
    assert_match(/QuickSMS SENDER_NOT_REGISTERED: Sender not registered/, error.message)

    stub_request(:post, SEND).to_return(status: 401, body: { error: { code: "UNAUTHORIZED", message: "Invalid API key" } }.to_json)
    error = assert_raises(RuntimeError) { Messaging::Quicksms.deliver(message) }
    assert_match(/QuickSMS 401: .*Invalid API key/, error.message)
  end

  test "the credentials check reads one message id: not found means the key works, unauthorized means it does not" do
    login_admin
    stub_request(:get, "https://api.quicksms.com/v2/messages/credential-check")
      .with(headers: { "Authorization" => "Bearer sk_live_good" }).to_return(status: 404, body: { error: { code: "NOT_FOUND" } }.to_json)
    post "/messages_quicksms_settings/test_credentials", params: { settings: { messages_quicksms_api_key: "sk_live_good" } }
    assert_equal true, response.parsed_body["success"]

    stub_request(:get, "https://api.quicksms.com/v2/messages/credential-check")
      .with(headers: { "Authorization" => "Bearer bad" }).to_return(status: 401, body: { error: { code: "UNAUTHORIZED", message: "Invalid API key" } }.to_json)
    post "/messages_quicksms_settings/test_credentials", params: { settings: { messages_quicksms_api_key: "bad" } }
    assert_equal false, response.parsed_body["success"]
    assert_match(/QuickSMS 401: .*Invalid API key/, response.parsed_body["message"])
  end

  test "the settings page and the Providers card exist and save the fields" do
    login_admin
    get "/messages_quicksms_settings"
    assert_response :success
    assert_select "input#quicksms-enabled"
    assert_select "input[name='settings[messages_quicksms_api_key]'][type=password]"
    assert_select "input[name='settings[messages_quicksms_from]']"
    assert_select "input[name='settings[messages_quicksms_signing_secret]'][type=password]"
    assert_select "#quicksms-test button#quicksms-send-test"
    assert_select "a[href='https://www.quicksms.com/']"

    post "/messages_quicksms_settings/save", params: { settings: {
      messages_quicksms_enabled: "1", messages_quicksms_api_key: "sk_live_x", messages_quicksms_from: "OpenOut",
      messages_quicksms_signing_secret: "whsec", messages_quicksms_incoming: "1"
    } }
    assert_equal [ "1", "sk_live_x", "OpenOut", "whsec", "1" ],
                 %w[enabled api_key from signing_secret incoming].map { |name| Setting.get("messages_quicksms_#{name}") }

    get "/messages_providers"
    assert_select ".card h5", text: "QuickSMS"
    assert_select ".card small", text: I18n.t("ea.messages_provider_quicksms_info")
  end

  def inbound(body, secret: nil, timestamp: Time.now.to_i.to_s)
    headers = { "CONTENT_TYPE" => "application/json" }
    if secret
      headers["X-QuickSMS-Timestamp"] = timestamp
      headers["X-QuickSMS-Signature"] = "sha256=" + OpenSSL::HMAC.hexdigest("sha256", secret, "#{timestamp}.#{body}")
    end
    post "/messages/inbound/quicksms/secrettoken123", params: body, headers: headers
  end

  test "the inbound webhook stores a signed V2 message for a known customer and rejects a bad signature" do
    enable_quicksms(incoming: "1", secret: "whsec")
    body = { from: users(:jx).phone_number, to: "447908679883", content: "On my way", channel: "sms",
             message_id: "in1", timestamp: "2026-06-17T11:41:24Z" }.to_json

    inbound(body, secret: "wrong")
    assert_response :forbidden
    inbound(body)
    assert_response :forbidden
    inbound(body, secret: "whsec", timestamp: (Time.now.to_i - 600).to_s)
    assert_response :forbidden

    inbound(body, secret: "whsec")
    assert_response :success
    message = Message.incoming.sole
    assert_equal [ users(:jx).id, "On my way", "quicksms", users(:jx).phone_number, "+447908679883" ],
                 [ message.customer_id, message.body, message.channel, message.from_address, message.to_address ]
  end

  test "without a signing secret the webhook relies on the URL token alone" do
    enable_quicksms(incoming: "1")
    inbound({ from: "+447700900999", to: "447908679883", content: "Who dis", channel: "sms", message_id: "in2" }.to_json)
    assert_response :success
    assert_nil Message.incoming.sole.customer_id
    assert_equal "Who dis", Message.incoming.sole.body
  end

  test "existing installs get the settings rows from the migration" do
    Setting.where("name LIKE 'messages_quicksms_%'").delete_all
    require Rails.root.glob("db/migrate/*_add_quicksms_settings.rb").first
    ActiveRecord::Migration.suppress_messages { AddQuicksmsSettings.new.up }
    assert_equal "0", Setting.find_by(name: "messages_quicksms_enabled").value
    assert_equal "", Setting.find_by(name: "messages_quicksms_api_key").value
  end
end
