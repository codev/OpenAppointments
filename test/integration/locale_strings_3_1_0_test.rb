require "test_helper"

# Every locale carries the 3.1.0 strings: the settings switches, the company
# address, the cancellation prompts and the send and receive wording; the
# Enable Sync button tooltip is gone.
class LocaleStrings310Test < ActionDispatch::IntegrationTest
  KEYS = %w[
    appointments_include_locations appointments_include_locations_hint
    appointments_include_meeting_links appointments_include_meeting_links_hint
    booking_provider_first_hint display_order_switch_hint cancel_reason_optional late_cancel_reason
    clear_providers clear_services company_address company_address_hint
    do_not_contact_hint do_not_contact_warning feed refresh sync
    messages_provider_incoming_outgoing messages_provider_outgoing messages_incoming_label messages_outgoing_label
  ].freeze
  DROPPED = %w[enable_appointment_sync_hint].freeze

  test "the 3.1.0 strings exist in every locale and the dropped keys are gone" do
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
      DROPPED.each do |key|
        assert_nil I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil), "ea.#{key} still in #{locale}"
      end
    end
    assert_equal "Send and receive", I18n.t("ea.messages_provider_incoming_outgoing", locale: :en)
    assert_equal "Send only", I18n.t("ea.messages_provider_outgoing", locale: :en)
    assert_equal "Received", I18n.t("ea.messages_incoming_label", locale: :en)
    assert_equal "Sent", I18n.t("ea.messages_outgoing_label", locale: :en)
    assert_equal "You're all set!", I18n.t("ea.appointment_registered", locale: :en)
  end

  test "the booking settings page shows the new switches" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/booking_settings"
    assert_select "label", text: I18n.t("ea.appointments_include_locations")
    assert_select "label", text: I18n.t("ea.appointments_include_meeting_links")
  end
end
