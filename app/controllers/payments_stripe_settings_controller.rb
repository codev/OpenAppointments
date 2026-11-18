class PaymentsStripeSettingsController < ApplicationController
  include PaymentsMethodSettingsPage

  METHOD_KEY = "stripe".freeze
  SETTING_NAMES = %w[payments_stripe_enabled payments_stripe_secret_key payments_stripe_webhook_secret
                     payments_stripe_currency].freeze

  private

  # The currency is a three letter ISO code, stored upper case.
  def clean_value(name, value)
    return value unless name == "payments_stripe_currency"

    code = value.to_s.strip.upcase
    raise ArgumentError, helpers.lang("payments_invalid_currency") unless code.match?(/\A[A-Z]{3}\z/)

    code
  end
end
