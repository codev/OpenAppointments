require "test_helper"

# Every locale carries the 3.4.0 payments strings.
class LocaleStrings340Test < ActionDispatch::IntegrationTest
  KEYS = %w[payments payments_methods payments_methods_info payments_enabled payments_enabled_hint
            payments_default_method payments_default_method_hint payments_method_in_person
            payments_method_bank_transfer payments_method_in_person_info payments_method_bank_transfer_info
            payments_method_stripe_info payments_instructions payments_instructions_hint payments_stripe_secret_key
            payments_stripe_keys_hint payments_stripe_webhook_secret payments_stripe_webhook_secret_hint
            payments_stripe_currency_hint payments_invalid_currency payment payments_choose confirm_and_pay
            payments_service_methods payments_service_methods_hint payments_method_inactive
            payments_method_not_offered payments_stripe_instructions payment_method payment_status payments_none
            paid unpaid payments_checkout_failed payments_redirecting payments_continue
            payments_not_completed_title payments_not_completed_text payments_try_again payments_cancel_booking
            payments_expired_title payments_expired_text payments_abandoned_text payments_book_again
            payments_stripe_webhook_url payments_stripe_webhook_url_hint].freeze

  test "the 3.4.0 strings exist in every locale" do
    assert_equal 46, KEYS.size
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
    end
    assert_equal "Confirm and pay", I18n.t("ea.confirm_and_pay", locale: :en)
  end
end
