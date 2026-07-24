# Messages > Logs: one line per sent/received message, newest first,
# server-rendered with simple pagination.
class MessagesLogsController < ApplicationController
  include BackendPage

  layout "backend"

  PER_PAGE = 50

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    page = [ params[:page].to_i, 1 ].max
    scope = Message.newest_first.includes(:customer, :notification)
    html_vars(
      log_messages: scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a,
      log_page: page,
      log_last_page: Message.count <= page * PER_PAGE
    )
    render :index
  end
end
