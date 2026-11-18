class PaymentsBankTransferSettingsController < ApplicationController
  include PaymentsMethodSettingsPage

  METHOD_KEY = "bank_transfer".freeze
  SETTING_NAMES = %w[payments_bank_transfer_enabled payments_bank_transfer_instructions].freeze
end
