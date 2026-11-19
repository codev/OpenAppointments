# Default settings rows for the payments system. Used by db/seeds.rb (fresh
# installs) and the add_payments_settings migration (existing installs).
module Payments
  module Defaults
    SETTINGS = {
      # Payments > Settings
      "payments_enabled" => "0",
      "payments_default_method" => "in_person",

      # Pay in person
      "payments_in_person_enabled" => "1",
      "payments_in_person_instructions" => "",

      # Bank transfer or any other method described in text
      "payments_bank_transfer_enabled" => "0",
      "payments_bank_transfer_instructions" => "",

      # Stripe Checkout
      "payments_stripe_enabled" => "0",
      "payments_stripe_secret_key" => "",
      "payments_stripe_webhook_secret" => "",
      "payments_stripe_currency" => "GBP"
    }.freeze
  end
end
