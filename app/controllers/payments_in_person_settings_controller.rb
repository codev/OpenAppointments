class PaymentsInPersonSettingsController < ApplicationController
  include PaymentsMethodSettingsPage

  METHOD_KEY = "in_person".freeze
  SETTING_NAMES = %w[payments_in_person_enabled payments_in_person_instructions].freeze
end
