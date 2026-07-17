# Resolves the request language (EA language name) and sets I18n.locale for the
# server-rendered lang() helper. Priority mirrors EA config.php: ?language= param,
# then the session, then the logged-in user, then the default_language setting.
module LocaleSelection
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
    helper_method :current_language
  end

  private

  def switch_locale
    persist_language_param
    I18n.with_locale(Localization.code_for(current_language)) { yield }
  end

  # EA language name (e.g. "english"), used for the window.lang payload and dropdown.
  def current_language
    @current_language ||= resolve_language
  end

  def resolve_language
    candidates = [ param_language, session[:language], current_user&.language, Setting.get("default_language") ]
    candidates.compact_blank.find { |name| Localization.available_languages.include?(name) } || "english"
  end

  # ?language= sets the session for the rest of the visit (EA behaviour).
  def persist_language_param
    name = param_language
    session[:language] = name if name && Localization.available_languages.include?(name)
  end

  def param_language
    value = params[:language].to_s
    value.blank? ? nil : value.gsub(/[^a-zA-Z0-9_-]/, "")
  end
end
