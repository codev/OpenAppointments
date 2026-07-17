# Port of EA's script_vars()/html_vars() pattern: controllers accumulate values that
# the layout injects as window.vars via the shared/js_vars_script partial.
module ScriptVars
  extend ActiveSupport::Concern

  included do
    helper_method :script_vars, :html_vars
  end

  # script_vars(key: value) merges; script_vars() returns the accumulated hash.
  def script_vars(values = nil)
    @script_vars ||= {}
    @script_vars.merge!(values) if values
    @script_vars
  end

  def html_vars(values = nil)
    @html_vars ||= {}
    @html_vars.merge!(values) if values
    @html_vars
  end

  # Vars every page needs, mirroring EA's config/layout defaults.
  def default_script_vars
    {
      base_url: request.base_url,
      index_page: "",
      csrf_token: form_authenticity_token,
      language: session[:language] || Setting.get("default_language", "english"),
      language_code: Localization.code_for(session[:language] || Setting.get("default_language", "english"))
    }
  end
end
