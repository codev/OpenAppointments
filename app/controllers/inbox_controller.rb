# Inbox: the admin task list of incoming customer messages, newest first.
# Filters: To Do (default), unread and not done, or Archive (done).
class InboxController < ApplicationController
  include BackendPage

  layout "backend"

  PER_PAGE = 50

  # Filter name => [path, label key], in button order.
  FILTERS = {
    "to_do" => [ "/inbox", "inbox_filter_to_do" ],
    "unread" => [ "/inbox?unread=1", "inbox_filter_unread" ],
    "archive" => [ "/inbox?done=1", "inbox_filter_archive" ]
  }.freeze

  def index
    return unless require_backend_page!(:customers)
    return head :forbidden unless inbox_access?

    backend_page_vars(page_title: helpers.lang("inbox"), active_menu: "inbox")
    page = [ params[:page].to_i, 1 ].max
    filter = "to_do"
    filter = "unread" if params[:unread] == "1"
    filter = "archive" if params[:done] == "1"
    scope = Message.inbox.includes(:customer, :done_by).newest_first
    scope = filter == "archive" ? scope.done : scope.not_done
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
