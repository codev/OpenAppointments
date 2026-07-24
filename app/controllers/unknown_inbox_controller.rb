# Incoming messages from senders that match no customer. Visible to admins and
# secretaries; visiting the page clears the header badge.
class UnknownInboxController < ApplicationController
  include BackendPage

  layout "backend"

  PER_PAGE = 50

  def index
    session[:dest_url] = request.original_url
    return redirect_to login_path unless logged_in?
    return head :forbidden unless [ Role::ADMIN, Role::SECRETARY ].include?(session[:role_slug])

    backend_page_vars(page_title: helpers.lang("unknown_inbox"), active_menu: "messages")
    page = [ params[:page].to_i, 1 ].max
    scope = Message.incoming.unknown_sender.newest_first
    html_vars(
      inbox_messages: scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a,
      inbox_page: page,
      inbox_last_page: Message.incoming.unknown_sender.count <= page * PER_PAGE
    )
    Message.mark_unknown_read
    render :index
  end
end
