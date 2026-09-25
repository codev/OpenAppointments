# Inbox: the admin task list of incoming customer messages, newest first.
# Filters: not done (default), unread and not done, or done.
class InboxController < ApplicationController
  include BackendPage

  layout "backend"

  PER_PAGE = 50

  def index
    return unless require_backend_page!(:customers)
    return head :forbidden unless inbox_access?

    backend_page_vars(page_title: helpers.lang("inbox"), active_menu: "inbox")
    page = [ params[:page].to_i, 1 ].max
    filter = if params[:done] == "1" then "done"
             elsif params[:unread] == "1" then "unread"
             else "all"
             end
    scope = Message.inbox.includes(:customer, :done_by).newest_first
    scope = filter == "done" ? scope.done : scope.not_done
    scope = scope.unread if filter == "unread"
    html_vars(
      inbox_messages: scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a,
      inbox_page: page,
      inbox_last_page: scope.count <= page * PER_PAGE,
      inbox_filter: filter
    )
    render :index
  end
end
