require "test_helper"

# Every locale carries the 3.5.1 Activity page strings.
class LocaleStrings351Test < ActionDispatch::IntegrationTest
  KEYS = %w[activity activity_hint activity_when activity_kind activity_actor activity_details activity_refresh
            activity_empty activity_all_kinds activity_appointment_booked activity_appointment_changed
            activity_appointment_cancelled activity_appointment_deleted activity_unavailability_saved
            activity_unavailability_deleted activity_message_sent activity_message_failed activity_message_received
            activity_waitlist_signup activity_reminders_marked activity_actor_booking_page activity_actor_api
            activity_actor_system activity_actor_import activity_appointment_summary activity_status_summary
            activity_reason_summary activity_message_summary activity_received_summary activity_waitlist_summary].freeze

  PLACEHOLDERS = {
    "activity_appointment_summary" => %w[service customer provider when],
    "activity_status_summary" => %w[status],
    "activity_reason_summary" => %w[reason],
    "activity_message_summary" => %w[notification audience channel address],
    "activity_received_summary" => %w[address channel],
    "activity_waitlist_summary" => %w[customer service provider]
  }.freeze

  test "the 3.5.1 strings exist in every locale with their placeholders" do
    assert_equal 30, KEYS.size
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        value = I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil)
        assert value.present?, "missing ea.#{key} in #{locale}"
        PLACEHOLDERS.fetch(key, []).each do |name|
          assert_includes value, "{{#{name}}}", "ea.#{key} in #{locale} lost {{#{name}}}"
        end
      end
    end
    assert_equal "Refresh every minute", I18n.t("ea.activity_refresh", locale: :en)
  end
end
