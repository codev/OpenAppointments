# Payments > Settings: the global switch and the default method.
class PaymentsSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  SETTING_NAMES = %w[payments_enabled payments_default_method].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("payments"), active_menu: "payments")
    render :index
  end

  # POST /payments_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:payments_settings, allowed_names: SETTING_NAMES) do |name, value|
      next value unless name == "payments_default_method"

      Payments.find(value) ? value : nil
    end
  rescue ArgumentError => e
    settings_failed(e)
  end
end
