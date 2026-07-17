# Port of EA's Integrations controller (settings hub page).
class IntegrationsController < ApplicationController
  include BackendPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("integrations"), active_menu: "system_settings")
    render :index
  end
end
