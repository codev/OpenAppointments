require "test_helper"

# Every locale carries the 3.2.5 strings: the notice shown on the page that
# confirms a booking, and the step 5 heading reworded as an instruction.
class LocaleStrings325Test < ActionDispatch::IntegrationTest
  KEYS = %w[booking_notice_confirmed_step messages_provider_default messages_default_provider
            messages_default_provider_hint messages_test_setup messages_test_credentials
            messages_test_credentials_ok messages_test_sending messages_test_send messages_test_sent
            messages_test_email_address messages_test_failed messages_test_outgoing_ok
            messages_test_outgoing_server messages_test_outgoing_failed messages_test_incoming_ok
            messages_test_incoming_off messages_test_incoming_failed].freeze
  # The Google Calendar and CalDAV sync strings went with the integrations.
  DROPPED = %w[synchronize enable_sync disable_sync disable_sync_prompt sync trigger_sync_hint
               calendar_sync_completed calendar_sync_failed select_sync_calendar select_sync_calendar_prompt
               sync_calendar_selected sync_method_prompt caldav_server caldav_connection_info_prompt connect
               calendar_url invalid_credentials_provided google_calendar google_calendar_info google_client_id
               google_client_id_info google_client_secret google_client_secret_info google_calendar_setup_info
               google_meet_link_generation google_meet_link_generation_info messages_test_sms messages_test_sms_sent].freeze

  test "the 3.2.5 strings exist in every locale and the dropped keys are gone" do
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
      DROPPED.each do |key|
        assert_nil I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil), "ea.#{key} still in #{locale}"
      end
    end
    assert_equal "Booking Notice - After Confirmation", I18n.t("ea.booking_notice_confirmed_step", locale: :en)
    assert_equal "Confirm Your Appointment", I18n.t("ea.appointment_confirmation", locale: :en)
  end
end
