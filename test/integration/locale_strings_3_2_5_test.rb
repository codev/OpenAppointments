require "test_helper"

# Every locale carries the 3.2.5 strings: the notice shown on the page that
# confirms a booking, and the step 5 heading reworded as an instruction.
class LocaleStrings325Test < ActionDispatch::IntegrationTest
  KEYS = %w[booking_notice_confirmed_step].freeze
  DROPPED = %w[].freeze

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
