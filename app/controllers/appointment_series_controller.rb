# Repeating appointments: list, change the pattern, cancel from a date. Backend
# roles only; providers see and change their own series. The list and the
# cancel form render inside the appointments page's series frame; the pattern
# dialog (a recurring_select widget) posts JSON.
class AppointmentSeriesController < ApplicationController
  include BackendPage

  layout "backend"

  before_action :require_session

  REPEAT_PERMIT = CalendarController::REPEAT_PERMIT

  # GET /appointment_series
  def index
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:view, :appointments)

    @series = visible_series.to_a
    respond_to do |format|
      format.html { render_panel }
      format.json { render json: @series.map { |series| EaRows.series_row(series) } }
    end
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # GET /appointment_series/:id/cancel - the cancel form for the frame.
  def cancel_form
    head :forbidden and return if cannot?(:delete, :appointments)

    @cancelling = visible_series.find(params[:id])
    @series = visible_series.to_a
    render_panel
  end

  # POST /appointment_series/:id/reschedule
  def reschedule
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:edit, :appointments)

    series = visible_series.find(params[:id])
    repeat = permitted_hash(params[:repeat], REPEAT_PERMIT)
    raise ArgumentError, "Invalid repeat pattern." if repeat.blank? || repeat["rule"].blank?

    result = series.reschedule!(repeat)
    series.announce(created: result[:rows], removed: result[:rescheduled],
                    notify: boolean_param(params.fetch(:notify_users, true)))
    render json: { success: true, skipped: result[:skipped], series: EaRows.series_row(series.reload) }
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    json_exception(e, status: :ok)
  end

  # POST /appointment_series/:id/cancel - from a date on, notifying customers as
  # for a single cancellation.
  def cancel
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:delete, :appointments)

    series = visible_series.find(params[:id])
    from = Date.parse(params.require(:from).to_s)
    notify_users = boolean_param(params.fetch(:notify_users, true))
    reason = params[:cancellation_reason].to_s

    deleted = series.cancel_from(from, reason: reason)
    series.announce(removed: deleted, notify: notify_users, reason: reason)

    respond_to do |format|
      format.html { redirect_to appointment_series_path, notice: helpers.lang("series_cancelled") }
      format.json { render json: { success: true, deleted: deleted.size } }
    end
  rescue ArgumentError, Date::Error, ActiveRecord::RecordNotFound => e
    respond_to do |format|
      format.html { redirect_to appointment_series_path, alert: e.message }
      format.json { json_exception(e, status: :ok) }
    end
  end

  private

  def render_panel
    backend_page_vars(page_title: helpers.lang("repeating_appointments"), active_menu: "appointments")
    render :index
  end

  def visible_series
    scope = AppointmentSeries.includes(:provider, :customer, :service).order(:starts_on)
    case session[:role_slug]
    when Role::PROVIDER then scope.for_provider(session[:user_id])
    when Role::ASSISTANT then scope.where(id_users_provider: assistant_provider_ids)
    else scope
    end
  end
end
