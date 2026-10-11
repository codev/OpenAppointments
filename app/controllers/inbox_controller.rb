# Inbox: the admin task list of incoming messages, newest first, from
# customers and unknown senders alike. Read state plays no part here: a
# message is in the Inbox until marked Done, then in the Archive.
class InboxController < ApplicationController
  include BackendPage

  layout "backend"

  PER_PAGE = 50

  # Filter name => [path, label key], in button order.
  FILTERS = {
    "inbox" => [ "/inbox", "inbox" ],
    "archive" => [ "/inbox?done=1", "inbox_filter_archive" ]
  }.freeze

  def index
    return unless require_backend_page!(:customers)
    return head :forbidden unless inbox_access?

    backend_page_vars(page_title: helpers.lang("inbox"), active_menu: "inbox")
    page = [ params[:page].to_i, 1 ].max
    filter = params[:done] == "1" ? "archive" : "inbox"
    scope = Message.incoming.includes(:customer, :done_by).newest_first
    scope = filter == "archive" ? scope.done : scope.not_done
    html_vars(
      inbox_messages: scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a,
      inbox_page: page,
      inbox_last_page: scope.count <= page * PER_PAGE,
      inbox_filter: filter
    )
    render :index
  end
end
