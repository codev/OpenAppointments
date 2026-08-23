# Backend calendar, port of EA's Calendar controller.
class CalendarController < ApplicationController
  include BackendPage
  include CalendarPage
  include EventSaving

  layout "backend"

  FILTER_TYPE_ALL = "all".freeze
  FILTER_TYPE_PROVIDER = "provider".freeze
  FILTER_TYPE_SERVICE = "service".freeze

  before_action :require_session, except: [ :index, :reschedule ]
  rescue_from EventSaving::Forbidden, with: -> { head :forbidden }

  def reschedule
    params[:appointment_hash] = params[:appointment_hash].to_s
    index
  end

  def index
    render_calendar_page(page_title: "calendar", active_menu: "calendar")
  end

  # POST /calendar/save_appointment (drag, resize and the EA API shape)
  def save_appointment
    result = store_appointment(
      permitted_hash(params[:appointment_data], APPOINTMENT_PERMIT),
      permitted_hash(params[:customer_data], CUSTOMER_PERMIT),
      permitted_hash(params[:repeat], REPEAT_PERMIT),
      notify_users: boolean_param(params.fetch(:notify_users, true)),
      force_save: boolean_param(params.fetch(:force_save, false))
    )
    render json: { success: true, id: result[:appointment].id, skipped: result[:skipped] }
  rescue EventSaving::Conflict => e
    render json: { success: false, conflict: true, message: e.message }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /calendar/delete_appointment: hard delete (admin tool).
  def delete_appointment
    remove_appointment("delete")
  end

  # POST /calendar/cancel_appointment: keeps the row with the cancelled status.
  def cancel_appointment
    remove_appointment("cancel")
  end

  # POST /calendar/save_unavailability
  def save_unavailability
    store_unavailability(permitted_hash(params[:unavailability], UNAVAILABILITY_PERMIT))
    render json: { success: true, warnings: [] }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /calendar/delete_unavailability
  def delete_unavailability
    remove_unavailability(Appointment.unavailabilities.find(params.require(:unavailability_id)))
    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /calendar/save_working_plan_exception
  def save_working_plan_exception
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:edit, :users)

    exception_data = permitted_hash(params[:working_plan_exception], EXCEPTION_PERMIT)
    provider_id = params.require(:provider_id)

    record = exception_data["id"].present? ? WorkingPlanException.find(exception_data["id"]) : WorkingPlanException.new
    record.assign_attributes(
      start_date: exception_data["startDate"] || exception_data["start_date"],
      end_date: exception_data["endDate"] || exception_data["end_date"] ||
                exception_data["startDate"] || exception_data["start_date"],
      start_time: exception_data["startTime"] || exception_data["start_time"],
      end_time: exception_data["endTime"] || exception_data["end_time"],
      breaks: (exception_data["breaks"] || []).to_json,
      id_users_provider: provider_id
    )
    record.save!

    render json: { success: true, id: record.id }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /calendar/delete_working_plan_exception
  def delete_working_plan_exception
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:edit, :users)

    WorkingPlanException.find(params.require(:exception_id)).destroy!
    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /calendar/get_calendar_appointments_for_table_view
  def get_calendar_appointments_for_table_view
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:view, :appointments)

    start_datetime = "#{params.require(:start_date)} 00:00:00"
    end_datetime = "#{params.require(:end_date)} 23:59:59"

    appointments = Appointment.appointments
                              .where("start_datetime >= ? AND end_datetime <= ?", start_datetime, end_datetime)
    unavailabilities = Appointment.unavailabilities
                                  .where("start_datetime >= ? AND end_datetime <= ?", start_datetime, end_datetime)

    render json: calendar_events_response(appointments, unavailabilities,
                                          params[:start_date], params[:end_date])
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /calendar/get_calendar_appointments
  def get_calendar_appointments
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:view, :appointments)

    record_id = params[:record_id]
    is_all = record_id == FILTER_TYPE_ALL
    filter_type = params[:filter_type]

    return render json: { appointments: [], unavailabilities: [] } if filter_type.blank? && !is_all

    unless is_all || [ FILTER_TYPE_PROVIDER, FILTER_TYPE_SERVICE ].include?(filter_type)
      raise ArgumentError, "Invalid filter type provided."
    end
    raise ArgumentError, "Invalid record ID provided." if !is_all && !record_id.to_s.match?(/\A\d+\z/)

    where_id = filter_type == FILTER_TYPE_SERVICE ? :id_services : :id_users_provider
    start_date = params.require(:start_date)
    end_date = (Date.parse(params.require(:end_date)) + 1).strftime("%Y-%m-%d")

    scope = Appointment.where(<<~SQL.squish, s: start_date, e: end_date)
      (start_datetime > :s AND start_datetime < :e)
      OR (end_datetime > :s AND end_datetime < :e)
      OR (start_datetime <= :s AND end_datetime >= :e)
    SQL
    scope = scope.where(where_id => record_id) unless is_all

    appointments = scope.appointments
    unavailabilities =
      if filter_type == FILTER_TYPE_PROVIDER || is_all
        scope.unavailabilities
      else
        Appointment.none
      end

    render json: calendar_events_response(appointments, unavailabilities,
                                          params[:start_date], params[:end_date])
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def remove_appointment(kind)
    remove_appointment_record(Appointment.find(params.require(:appointment_id)), kind: kind,
                              reason: params[:cancellation_reason].to_s,
                              notify_users: boolean_param(params.fetch(:notify_users, true)))
    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  def calendar_events_response(appointments, unavailabilities, start_date, end_date)
    appointments = filter_events_by_role(appointments.includes(:provider, :service, :customer)).to_a
    unavailabilities = filter_events_by_role(unavailabilities.includes(:provider))
    unread_counts = Message.unread_counts_for(appointments.filter_map(&:id_users_customer).uniq)

    {
      appointments: appointments.map do |appointment|
        EaRows.appointment_row(appointment).merge(
          "provider" => appointment.provider && EaRows.provider_row(appointment.provider),
          "service" => appointment.service && EaRows.service_row(appointment.service),
          "customer" => appointment.customer && EaRows.customer_row(appointment.customer)
                          .merge("unread_messages" => unread_counts[appointment.customer.id] || 0)
        )
      end,
      unavailabilities: unavailabilities.map do |unavailability|
        EaRows.appointment_row(unavailability).merge(
          "provider" => unavailability.provider && EaRows.provider_row(unavailability.provider)
        )
      end,
      blocked_periods: BlockedPeriod.for_period(start_date, end_date).map { |p| EaRows.blocked_period_row(p) }
    }
  end

  def filter_events_by_role(events)
    case session[:role_slug]
    when Role::PROVIDER
      events.where(id_users_provider: session[:user_id])
    when Role::ASSISTANT
      events.where(id_users_provider: assistant_provider_ids)
    else
      events
    end
  end

  CUSTOMER_PERMIT = EventSaving::CUSTOMER_FIELDS.map(&:to_sym).freeze
  APPOINTMENT_PERMIT = EventSaving::APPOINTMENT_FIELDS.map(&:to_sym).freeze
  REPEAT_PERMIT = %i[rule ends ends_on count].freeze
  UNAVAILABILITY_PERMIT = EventSaving::UNAVAILABILITY_FIELDS.map(&:to_sym).freeze
  EXCEPTION_PERMIT = [ :id, :startDate, :endDate, :startTime, :endTime, :start_date, :end_date,
                      :start_time, :end_time, { breaks: [ :start, :end ] } ].freeze
end
