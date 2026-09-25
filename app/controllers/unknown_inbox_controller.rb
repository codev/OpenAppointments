# Incoming messages from senders that match no customer. Admins only, with the
# same Done / Show done as the Inbox.
class UnknownInboxController < ApplicationController
  include BackendPage

  layout "backend"

  PER_PAGE = 50

  def index
    session[:dest_url] = request.original_url
    return redirect_to login_path unless logged_in?
    return head :forbidden unless inbox_access?

    backend_page_vars(page_title: helpers.lang("unknown_inbox"), active_menu: "messages")
    page = [ params[:page].to_i, 1 ].max
    show_done = params[:done] == "1"
    scope = Message.incoming.unknown_sender.includes(:done_by).newest_first
    scope = show_done ? scope.done : scope.not_done
    html_vars(
      inbox_messages: scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a,
      inbox_page: page,
      inbox_last_page: scope.count <= page * PER_PAGE,
      inbox_show_done: show_done
    )
    render :index
  end
end
