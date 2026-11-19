# Shared shape of the methods that only show text: an Active switch and the
# instructions shown to the customer. Nothing is checked or collected.
module Payments
  module TextMethod
    def checkout? = false

    # Staff mark the appointment paid when the money arrives.
    def tracks_payment? = true

    def enabled?(config = Payments.config) = config["payments_#{key}_enabled"] == "1"

    def instructions(config = Payments.config) = config["payments_#{key}_instructions"].to_s
  end
end
