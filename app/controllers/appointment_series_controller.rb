# Repeating appointments: list, change the pattern, cancel from a date. Backend
# roles only; providers see and change their own series.
class AppointmentSeriesController < ApplicationController
  include BackendPage

  before_action :require_session

  REPEAT_PERMIT = CalendarController::REPEAT_PERMIT

  # GET /appointment_series
  def index
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:view, :appointments)

    render json: visible_series.map { |series| EaRows.series_row(series) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /appointment_series/:id/reschedule
  def reschedule
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:edit, :appointments)

    series = visible_series.find(params[:id])
    repeat = permitted_hash(params[:repeat], REPEAT_PERMIT)
    raise ArgumentError, "Invalid repeat pattern." if repeat.blank? || repeat["rule"].blank?

    result = series.reschedule!(repeat)
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

    deleted = series.cancel_from(from)
    deleted.each do |appointment|
      if notify_users
        Notifications.appointment_deleted(appointment, appointment.service, appointment.provider,
                                          appointment.customer, nil, reason: reason)
      end
      Synchronization.appointment_deleted(appointment, appointment.provider)
      Webhooks.trigger(Webhooks::APPOINTMENT_DELETE, appointment)
    end

    render json: { success: true, deleted: deleted.size }
  rescue ArgumentError, Date::Error, ActiveRecord::RecordNotFound => e
    json_exception(e, status: :ok)
  end

  private

  def visible_series
    scope = AppointmentSeries.includes(:provider, :customer, :service).order(:starts_on)
    case session[:role_slug]
    when Role::PROVIDER then scope.for_provider(session[:user_id])
    when Role::ASSISTANT then scope.where(id_users_provider: assistant_provider_ids)
    else scope
    end
  end
end
