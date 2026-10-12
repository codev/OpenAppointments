require "test_helper"

# Every backend form ends with one row of action buttons at the bottom right:
# Delete, Cancel, Save, with Save last and marked for the disabled-until-changed
# script (data-save). Pop-up dialogs keep their own footers.
class FormActionsTest < ActionDispatch::IntegrationTest
  SETTINGS_PAGES = %w[
    general_settings business_settings booking_settings legal_settings theme_settings altcha_settings
    api_settings embed_settings google_analytics_settings google_calendar_settings jitsi_settings
    ldap_settings matomo_analytics_settings umami_analytics_settings messages_settings
    messages_email_settings messages_twilio_settings messages_plivo_settings messages_textanywhere_settings
    messages_smsgateway_settings
  ].freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def action_labels(selector)
    css_select("#{selector} > .form-actions:last-child").first.css("a, button").map { |el| el.text.strip }
  end

  test "settings pages save from the bottom of the form, not the header" do
    login_admin
    SETTINGS_PAGES.each do |page|
      get "/#{page}"
      assert_select "form#settings-form > .form-actions:last-child button#save-settings[type=submit][data-save]", 1, page
      assert_select ".border-bottom #save-settings", 0, "#{page} still has Save in the header"
    end
  end

  test "the account page saves from the bottom of its form" do
    login_admin
    get "/account"
    assert_select "#account-form > .form-actions:last-child button#save-settings[type=submit][data-save]"
    assert_select ".border-bottom #save-settings", 0
  end

  test "record forms end with Delete, Cancel and Save" do
    login_admin
    get "/customers/#{users(:jx).id}/edit"
    assert_equal %w[Delete Cancel Save], action_labels("form.crud-form")
    # Delete pushed to the far left, Cancel and Save together on the right.
    assert_select "form.crud-form > .form-actions > button.btn-outline-danger.me-auto:first-child", text: /Delete/
    assert_select "form.crud-form > .form-actions button[type=submit][data-save]", text: /Save/
    get "/services/new"
    assert_equal %w[Cancel Save], action_labels("form.crud-form")
  end

  test "notification templates end with Delete and Save" do
    Messaging::Defaults.create_notifications!
    login_admin
    get "/messages_notifications"
    form = css_select(".notification-form").find { |f| f.at_css(".delete-notification") }
    assert_equal %w[Delete Save], form.css(".form-actions:last-child button").map { |el| el.text.strip }
    assert form.at_css(".form-actions button.save-notification[data-save]")
    assert form.at_css(".form-actions > button.delete-notification.me-auto:first-child"), "Delete at the far left"
  end
end
