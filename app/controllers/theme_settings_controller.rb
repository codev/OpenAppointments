# Theme and brand colour settings page (split out of General Settings).
class ThemeSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  ALLOWED_SETTINGS = %w[theme company_color company_secondary_color company_background_color].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("theme"), active_menu: "system_settings")
    script_vars(
      theme_settings: settings_rows.select { |row| ALLOWED_SETTINGS.include?(row["name"]) },
      theme_suggestions: Themes::SUGGESTED
    )
    html_vars(available_themes: available_themes)
    render :index
  end

  HEX_COLOR = /\A#\h{6}\z/

  # GET /theme_settings/preview. Standalone sample page loaded inside the theme
  # cards; colours come from the (possibly unsaved) pickers via params.
  def preview
    return unless require_backend_page!(:system_settings)

    @theme = params[:theme].to_s
    @theme = "nice" unless available_themes.include?(@theme)
    @colors = %i[primary secondary background].to_h { |key|
      value = params[key].to_s
      [ key, value.match?(HEX_COLOR) ? value : nil ]
    }
    render :preview, layout: false
  end

  # POST /theme_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:theme_settings, allowed_names: ALLOWED_SETTINGS)
  rescue ArgumentError => e
    json_exception(e)
  end

  private

  def available_themes
    Rails.root.glob("app/assets/builds/themes/*.css").map { |path| path.basename(".css").to_s }.sort
  end
end
