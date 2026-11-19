# The customer pays by bank transfer or whatever the instructions describe.
module Payments
  module BankTransfer
    extend TextMethod
    module_function

    def key = "bank_transfer"

    def label = I18n.t("ea.payments_method_bank_transfer")
  end
end
