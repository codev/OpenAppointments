require "test_helper"

# Every locale carries the 3.7.0 SMS delivery strings.
class LocaleStrings370Test < ActionDispatch::IntegrationTest
  KEYS = %w[messages_status_delivered messages_smsgateway_phone messages_smsgateway_phone_last_seen
            messages_smsgateway_phone_waiting messages_smsgateway_phone_stale
            messages_smsgateway_phone_unreachable messages_smsgateway_phone_failed].freeze

  PLACEHOLDERS = {
    "messages_smsgateway_phone_last_seen" => "{{when}}",
    "messages_smsgateway_phone_waiting" => "{{count}}",
    "messages_smsgateway_phone_unreachable" => "{{error}}",
    "messages_smsgateway_phone_failed" => "{{reason}}"
  }.freeze

  test "the 3.7.0 strings exist in every locale with their placeholders" do
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        value = I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil)
        assert value.present?, "missing ea.#{key} in #{locale}"
      end
      PLACEHOLDERS.each do |key, placeholder|
        assert_includes I18n.t("ea.#{key}", locale: locale), placeholder, "ea.#{key} in #{locale} lost #{placeholder}"
      end
    end
    assert_equal "Delivered", I18n.t("ea.messages_status_delivered", locale: :en)
  end
end
