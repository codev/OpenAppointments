# Port of EA's About controller.
class AboutController < ApplicationController
  include BackendPage

  layout "backend"

  def index
    return unless require_backend_page!(:user_settings)

    backend_page_vars(page_title: helpers.lang("about"), active_menu: "system_settings")
    render :index
  end
end
