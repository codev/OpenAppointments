# Port of EA's About controller. The upstream RSS blog feed is not fetched; the
# page shows its load-error fallback instead.
class AboutController < ApplicationController
  include BackendPage

  layout "backend"

  def index
    return unless require_backend_page!(:user_settings)

    backend_page_vars(page_title: helpers.lang("about"), active_menu: "system_settings")
    html_vars(blog_posts: [])
    render :index
  end
end
