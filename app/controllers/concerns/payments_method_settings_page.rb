# Shared behavior of the per-method payments settings pages: admin-gated, saves
# a whitelisted name list plus the Default switch, and runs Test credentials on
# the form as posted (a blank secret standing for the stored one).
module PaymentsMethodSettingsPage
  extend ActiveSupport::Concern

  included do
    include BackendPage
    include SettingsPage

    layout "backend"

    before_action :forbid_unless_system_settings_edit
  end

  def index
    backend_page_vars(page_title: helpers.lang("payments"), active_menu: "payments")
    html_vars(**page_vars)
    render :index
  end

  def save
    require_system_settings_edit!
    save_setting_rows(self.class.controller_path.to_sym, allowed_names: self.class::SETTING_NAMES + [ default_switch_name ]) do |name, value|
      next clean_value(name, value) unless name == default_switch_name

      apply_default_switch(value)
      nil
    end
  rescue ArgumentError => e
    settings_failed(e)
  end

  # POST .../test_credentials: {success, message} from the method's check.
  def test_credentials
    require_system_settings_edit!
    ok, message = payment_method.check_credentials(posted_config)
    render json: { success: ok, message: message.presence || helpers.lang("messages_test_credentials_ok") }
  rescue ArgumentError => e
    render json: { success: false, message: e.message }
  end

  private

  def payment_method = Payments.find(self.class::METHOD_KEY)

  # Hook for pages with more to show than the settings.
  def page_vars = {}

  # Hook for pages that normalise or validate a value; raises ArgumentError to refuse.
  def clean_value(_name, value) = value

  # The form's values by name, stripped; blank secrets are already dropped.
  def posted_settings
    @posted_settings ||= setting_row_params(self.class.controller_path.to_sym)
                           .to_h { |row| [ row["name"], row["value"].to_s.strip ] }
                           .slice(*self.class::SETTING_NAMES)
  end

  def posted_config = Payments.config(posted_settings)

  # The page's Default switch posts as payments_<key>_default; it is not a
  # setting of its own but writes the one payments_default_method row.
  def default_switch_name = "payments_#{self.class::METHOD_KEY}_default"

  # On makes this method the default (any other loses it); off clears the
  # default only when it is this method.
  def apply_default_switch(value)
    key = self.class::METHOD_KEY
    if value == "1"
      Setting.set("payments_default_method", key)
    elsif Payments.default_method_key == key
      Setting.set("payments_default_method", "")
    end
  end
end
