# The customer pays at the appointment.
module Payments
  module InPerson
    extend TextMethod
    module_function

    def key = "in_person"

    def label = I18n.t("ea.payments_method_in_person")
  end
end
