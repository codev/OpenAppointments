# The Waiting List page: who is waiting for what, reached from Customers.
class WaitlistController < ApplicationController
  include BackendPage

  layout "backend"

  def index
    return unless require_backend_page!(:customers)

    backend_page_vars(page_title: helpers.lang("waitlist"), active_menu: "customers")
    @entries = WaitlistEntry.live.oldest_first.includes(:service, :provider)
    render :index
  end

  # DELETE /waitlist/:id
  def destroy
    return head :forbidden unless logged_in? && can?(:edit, :customers)

    WaitlistEntry.find(params[:id]).destroy!
    redirect_to "/waitlist"
  end
end
