# Embedding settings page: toggle iframe embedding, set the parent origin and
# copy the paste-ready embed code.
class EmbedSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  before_action :forbid_unless_system_settings_edit

  def index
    backend_page_vars(page_title: helpers.lang("embedding"), active_menu: "system_settings")
    script_vars(
      embed_settings: [
        { "name" => "allow_iframe_embedding", "value" => Setting.get("allow_iframe_embedding", "0") },
        { "name" => "iframe_embed_origin", "value" => Setting.get("iframe_embed_origin", "") }
      ]
    )
    html_vars(booking_url: request.base_url, embed_origin: Embedding.origin)
    render :index
  end

  # POST /embed_settings/save
  def save
    save_setting_rows(:embed_settings, allowed_names: %w[allow_iframe_embedding iframe_embed_origin])
  rescue ArgumentError => e
    json_exception(e)
  end
end
