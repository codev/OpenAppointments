require "test_helper"

# Default provider: one message provider, chosen with the Default switch on its
# settings page, is pre-selected in the customer page composer and badged on the
# Providers list. Switching it on for another provider moves it; only an enabled
# provider counts.
class MessagesDefaultProviderTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def enable_twilio
    Setting.set("messages_twilio_enabled", "1")
    Setting.set("messages_twilio_account_sid", "AC123")
    Setting.set("messages_twilio_auth_token", "tok")
    Setting.set("messages_twilio_from", "+447700900000")
  end

  test "the switch on a provider page sets that provider as the default and moves it" do
    login_admin
    post "/messages_twilio_settings/save", params: { settings: { messages_twilio_default: "1" } }
    assert_equal "twilio", Setting.get("messages_default_channel")

    post "/messages_email_settings/save", params: { settings: { messages_email_default: "1" } }
    assert_equal "email", Setting.get("messages_default_channel")

    get "/messages_email_settings"
    assert_select "input#email-default[name='settings[messages_email_default]'][checked]"
    get "/messages_twilio_settings"
    assert_select "input#twilio-default[name='settings[messages_twilio_default]']"
    assert_select "input#twilio-default[checked]", 0
    assert_select ".form-text", text: I18n.t("ea.messages_default_provider_hint")
  end

  test "switching the default off on its own page clears it, elsewhere it is left alone" do
    login_admin
    Setting.set("messages_default_channel", "email")
    post "/messages_twilio_settings/save", params: { settings: { messages_twilio_default: "0" } }
    assert_equal "email", Setting.get("messages_default_channel")

    post "/messages_email_settings/save", params: { settings: { messages_email_default: "0" } }
    assert_equal "", Setting.get("messages_default_channel").to_s
  end

  test "the SMS Gateway page handles the switch through its own save" do
    login_admin
    post "/messages_smsgateway_settings/save", params: { settings: { messages_smsgateway_default: "1" } }
    assert_equal "smsgateway", Setting.get("messages_default_channel")
  end

  test "the Providers list badges the enabled default in green" do
    login_admin
    Setting.set("messages_default_channel", "twilio")
    get "/messages_providers"
    assert_select ".badge.bg-success", text: I18n.t("ea.messages_provider_default"), count: 0

    enable_twilio
    get "/messages_providers"
    assert_select ".card-header .badge.bg-success", text: I18n.t("ea.messages_provider_default"), count: 1
    assert_select ".card-header .badge", text: I18n.t("ea.messages_provider_outgoing")
  end

  test "the composer pre-selects an enabled default and nothing otherwise" do
    login_admin
    enable_twilio
    Setting.set("messages_default_channel", "twilio")
    get "/customers/#{users(:jx).id}/messages"
    assert_select "#customer-message-composer #message-channel[value='twilio']"
    assert_select "#customer-message-composer #message-channel-button.channel-twilio", text: "Twilio"

    Setting.set("messages_twilio_enabled", "0")
    get "/customers/#{users(:jx).id}/messages"
    assert_select "#customer-message-composer #message-channel[value='']"
    assert_select "#customer-message-composer #message-channel-button", text: I18n.t("ea.select_one")
  end

  test "the registry exposes the default only while enabled" do
    Setting.set("messages_default_channel", "twilio")
    assert_nil Messaging.default_channel
    enable_twilio
    assert_equal Messaging::Twilio, Messaging.default_channel
    assert_equal Messaging::Twilio, Messaging.default_channel
  end
end
