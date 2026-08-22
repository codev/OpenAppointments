# Central inbox: incoming customer messages the user may see (BackendPage
# inbox_scope), newest first, with an unread-only filter.
class InboxController < ApplicationController
  include BackendPage

  layout "backend"

  PER_PAGE = 50

  def index
    return unless require_backend_page!(:customers)

    backend_page_vars(page_title: helpers.lang("inbox"), active_menu: "inbox")
    page = [ params[:page].to_i, 1 ].max
    unread_only = params[:unread] == "1"
    scope = inbox_scope.includes(:customer).newest_first
    scope = scope.unread if unread_only
    html_vars(
      inbox_messages: scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a,
      inbox_page: page,
      inbox_last_page: scope.count <= page * PER_PAGE,
      inbox_unread_only: unread_only
    )
    render :index
  end
end
