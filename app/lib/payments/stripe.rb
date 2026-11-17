# Stripe Checkout (https://dashboard.stripe.com/). The customer is sent to a
# hosted payment page after confirming the booking.
module Payments
  module Stripe
    module_function

    def key = "stripe"

    def label = "Stripe"

    def checkout? = true

    def enabled?(config = Payments.config)
      config["payments_stripe_enabled"] == "1" && secret_key(config).present?
    end

    def secret_key(config = Payments.config) = config["payments_stripe_secret_key"]

    def webhook_secret(config = Payments.config) = config["payments_stripe_webhook_secret"]

    def currency(config = Payments.config) = config["payments_stripe_currency"].to_s.downcase

    def instructions(_config = Payments.config) = ""
  end
end
