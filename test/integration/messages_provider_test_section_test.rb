require "test_helper"
require "webmock/minitest"

# Test setup on every provider page: Test credentials checks the values as they
# stand in the form (a blank secret keeps the stored one) against the provider,
# Test sending delivers one message to a given address the same way, logged in
# the Messages log. Nothing has to be saved first.
class MessagesProviderTestSectionTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  PROVIDERS = %w[email smsgateway twilio plivo textanywhere].freeze
  BASE = "https://sms.example.org".freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def store_gateway
    Setting.set("messages_smsgateway_enabled", "1")
    Setting.set("messages_smsgateway_url", "#{BASE}/")
    Setting.set("messages_smsgateway_login", "NAWFKJ")
    Setting.set("messages_smsgateway_password", "secretpw")
  end

  test "every provider page shows the test section with both buttons" do
    login_admin
    PROVIDERS.each do |key|
      get "/messages_#{key}_settings"
      assert_response :success
      assert_select "##{key}-test:not(.d-none) h5", text: I18n.t("ea.messages_test_setup")
      assert_select "##{key}-test button##{key}-test-credentials[data-no-change]", text: I18n.t("ea.messages_test_credentials")
      assert_select "##{key}-test label", text: I18n.t("ea.messages_test_sending")
      assert_select "##{key}-test input##{key}-test-address"
      assert_select "##{key}-test button##{key}-send-test[data-no-change]", text: I18n.t("ea.messages_test_send")
      assert_select "##{key}-test .test-result"
      assert_select "script[src*='pages/messages_provider_settings']"
    end
    get "/messages_email_settings"
    assert_select "#email-test input#email-test-address[type=email]"
    get "/messages_twilio_settings"
    assert_select "#twilio-test input#twilio-test-address[type=text][placeholder='07...']"
  end

  test "Twilio credentials are checked with the posted values and a blank token keeps the stored one" do
    login_admin
    Setting.set("messages_twilio_auth_token", "storedtoken")
    stub_request(:get, "https://api.twilio.com/2010-04-01/Accounts/ACposted.json")
      .with(basic_auth: [ "ACposted", "storedtoken" ]).to_return(status: 200, body: "{}")
    post "/messages_twilio_settings/test_credentials",
         params: { settings: { messages_twilio_account_sid: "ACposted", messages_twilio_auth_token: "" } }
    assert_equal true, response.parsed_body["success"]
    assert_equal I18n.t("ea.messages_test_credentials_ok"), response.parsed_body["message"]

    stub_request(:get, "https://api.twilio.com/2010-04-01/Accounts/ACbad.json")
      .to_return(status: 401, body: { message: "Authenticate" }.to_json)
    post "/messages_twilio_settings/test_credentials",
         params: { settings: { messages_twilio_account_sid: "ACbad", messages_twilio_auth_token: "nope" } }
    assert_equal false, response.parsed_body["success"]
    assert_match(/Twilio 401/, response.parsed_body["message"])
    assert_match(/Authenticate/, response.parsed_body["message"])
  end

  test "Plivo, TextAnywhere and SMS Gateway credential checks call their account endpoints" do
    login_admin
    stub_request(:get, "https://api.plivo.com/v1/Account/MAposted/")
      .with(basic_auth: [ "MAposted", "ptoken" ]).to_return(status: 200, body: "{}")
    post "/messages_plivo_settings/test_credentials",
         params: { settings: { messages_plivo_auth_id: "MAposted", messages_plivo_auth_token: "ptoken" } }
    assert_equal true, response.parsed_body["success"]

    stub_request(:get, "https://api.textanywhere.com/API/v1.0/REST/status")
      .with(headers: { "Authorization" => "Bearer takey" }).to_return(status: 200, body: "{}")
    post "/messages_textanywhere_settings/test_credentials", params: { settings: { messages_textanywhere_api_key: "takey" } }
    assert_equal true, response.parsed_body["success"]

    stub_request(:get, "#{BASE}/api/3rdparty/v1/device").with(basic_auth: [ "me", "pw" ]).to_return(status: 401)
    post "/messages_smsgateway_settings/test_credentials",
         params: { settings: { messages_smsgateway_url: BASE, messages_smsgateway_login: "me", messages_smsgateway_password: "pw" } }
    assert_equal false, response.parsed_body["success"]
    assert_match(/wrong API login or password/, response.parsed_body["message"])
  end

  test "a test send uses the posted credentials rather than the saved ones and is logged" do
    login_admin
    store_gateway
    other = "https://other.example.org"
    stub_request(:post, "#{other}/api/3rdparty/v1/message").with(basic_auth: [ "newlogin", "newpw" ])
      .to_return(status: 201, body: "{}")

    post "/messages_smsgateway_settings/test_send", params: {
      address: "07971 862965",
      settings: { messages_smsgateway_url: other, messages_smsgateway_login: "newlogin", messages_smsgateway_password: "newpw" }
    }
    assert_equal true, response.parsed_body["success"]
    assert_equal I18n.t("ea.messages_test_sent"), response.parsed_body["message"]
    message = Message.order(id: :desc).first
    assert_equal [ "smsgateway", "outgoing", "sent", "+447971862965" ],
                 [ message.channel, message.direction, message.status, message.to_address ]
    assert_not_requested(:post, "#{BASE}/api/3rdparty/v1/message")
    assert_equal "#{BASE}/", Setting.get("messages_smsgateway_url"), "a test never saves"

    stub_request(:post, "#{other}/api/3rdparty/v1/message").to_return(status: 400, body: { message: "invalid phone number" }.to_json)
    post "/messages_smsgateway_settings/test_send", params: {
      address: "07971862965",
      settings: { messages_smsgateway_url: other, messages_smsgateway_login: "newlogin", messages_smsgateway_password: "newpw" }
    }
    assert_equal false, response.parsed_body["success"]
    assert_match(/invalid phone number/, response.parsed_body["message"])
    assert_equal "failed", Message.order(id: :desc).first.status
  end

  test "a Twilio test send posts from the posted number and the country switch applies as posted" do
    login_admin
    stub_request(:post, "https://api.twilio.com/2010-04-01/Accounts/AC1/Messages.json").to_return(status: 201, body: "{}")
    settings = { messages_twilio_account_sid: "AC1", messages_twilio_auth_token: "t", messages_twilio_from: "+447700900000" }
    post "/messages_twilio_settings/test_send", params: { address: "07971862965", settings: settings }
    assert_equal true, response.parsed_body["success"]
    assert_requested(:post, "https://api.twilio.com/2010-04-01/Accounts/AC1/Messages.json") do |req|
      body = Rack::Utils.parse_nested_query(req.body)
      body["From"] == "+447700900000" && body["To"] == "+447971862965"
    end

    post "/messages_twilio_settings/test_send",
         params: { address: "+15551234567", settings: settings.merge(messages_twilio_default_country_only: "1") }
    assert_equal false, response.parsed_body["success"]
    assert_match(/outside the default country/, response.parsed_body["message"])

    post "/messages_twilio_settings/test_send", params: { address: "", settings: settings }
    assert_equal false, response.parsed_body["success"]
  end

  test "email credentials: server mode has nothing to check, SMTP mode reports the connection error" do
    login_admin
    post "/messages_email_settings/test_credentials",
         params: { settings: { messages_email_mode: "server", messages_email_incoming: "0" } }
    assert_equal true, response.parsed_body["success"]
    assert_includes response.parsed_body["message"], I18n.t("ea.messages_test_outgoing_server")
    assert_includes response.parsed_body["message"], I18n.t("ea.messages_test_incoming_off")

    post "/messages_email_settings/test_credentials", params: { settings: {
      messages_email_mode: "smtp", messages_email_smtp_host: "127.0.0.1", messages_email_smtp_port: "1",
      messages_email_smtp_username: "u", messages_email_smtp_password: "p", messages_email_smtp_tls: "0",
      messages_email_incoming: "1", messages_email_incoming_mode: "imap", messages_email_imap_host: "127.0.0.1",
      messages_email_imap_port: "1", messages_email_imap_username: "u", messages_email_imap_password: "p"
    } }
    assert_equal false, response.parsed_body["success"]
    assert_includes response.parsed_body["message"], I18n.t("ea.messages_test_outgoing_failed")
    assert_includes response.parsed_body["message"], I18n.t("ea.messages_test_incoming_failed")
    assert_match(/refused|connect/i, response.parsed_body["message"])
  end

  test "an email test send goes to the address and is logged" do
    login_admin
    assert_emails 1 do
      post "/messages_email_settings/test_send",
           params: { address: "someone@example.org", settings: { messages_email_mode: "server" } }
    end
    assert_equal true, response.parsed_body["success"]
    message = Message.order(id: :desc).first
    assert_equal [ "email", "sent", "someone@example.org" ], [ message.channel, message.status, message.to_address ]
    assert_equal [ "someone@example.org" ], ActionMailer::Base.deliveries.last.to

    post "/messages_email_settings/test_send", params: { address: "not-an-address", settings: {} }
    assert_equal false, response.parsed_body["success"]
  end

  test "the old test sms route is gone and the actions need the edit privilege" do
    login_admin
    post "/messages_smsgateway_settings/test_sms", params: { number: "07971862965" }
    assert_response :not_found

    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    post "/messages_twilio_settings/test_credentials", params: { settings: {} }
    assert_response :forbidden
  end
end
