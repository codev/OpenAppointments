# Admin Activity page: what the system did, newest first, with a kind filter
# and an optional reload every minute so it can be left open on launch day.
class ActivityController < ApplicationController
  include BackendPage

  layout "backend"

  PER_PAGE = 50

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("activity"), active_menu: "system_settings")
    kind = params[:kind].to_s
    kind = "" unless Activity::KINDS.include?(kind)
    page = [ params[:page].to_i, 1 ].max
    scope = ActivityEvent.newest_first.includes(:customer, :appointment)
    scope = scope.of_kind(kind) if kind.present?
    html_vars(
      activity_events: scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a,
      activity_kind: kind,
      activity_page: page,
      activity_last_page: scope.count <= page * PER_PAGE,
      activity_refresh: params[:refresh].to_s != "0"
    )
    render :index
  end
end
