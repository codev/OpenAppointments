# Shared shape of the methods that only show text: an Active switch and the
# instructions shown to the customer. Nothing is checked or collected.
module Payments
  module TextMethod
    def checkout? = false

    def enabled?(config = Payments.config) = config["payments_#{key}_enabled"] == "1"

    def instructions(config = Payments.config) = config["payments_#{key}_instructions"].to_s
  end
end
