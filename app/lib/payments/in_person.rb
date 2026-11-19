# The customer pays at the appointment.
module Payments
  module InPerson
    extend TextMethod
    module_function

    def key = "in_person"

    def label = I18n.t("ea.payments_method_in_person")

    # Settled at the till; the booking is not marked unpaid until then.
    def tracks_payment? = false
  end
end
