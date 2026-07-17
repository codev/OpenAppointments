# Backend calendar, port of EA's Calendar controller.
class CalendarController < ApplicationController
  include BackendPage

  layout "backend"

  FILTER_TYPE_ALL = "all".freeze
  FILTER_TYPE_PROVIDER = "provider".freeze
  FILTER_TYPE_SERVICE = "service".freeze

  before_action :require_session, except: [ :index, :reschedule ]

  def reschedule
    params[:appointment_hash] = params[:appointment_hash].to_s
    index
  end

  def index
    return unless require_backend_page!(:appointments)

    appointment_hash = params[:appointment_hash].to_s
    edit_appointment = nil
    if appointment_hash.present?
      record = Appointment.find_by(booking_hash: appointment_hash)
      if record
        edit_appointment = EaRows.appointment_row(record)
        edit_appointment["customer"] = EaRows.customer_row(record.customer) if record.customer
      end
    end

    available_providers = visible_providers.map { |provider| EaRows.provider_row(provider) }

    provider_service_ids = available_providers.flat_map { |provider| provider["services"] }.uniq
    category_names = ServiceCategory.pluck(:id, :name).to_h
    available_services = Service.available.joins(:provider_links).distinct.order(:name)
                                .select { |service| provider_service_ids.include?(service.id) }
                                .map do |service|
      # EA get_available_services shape includes the category id/name aliases.
      EaRows.service_row(service).merge(
        "service_category_id" => service.id_service_categories,
        "service_category_name" => category_names[service.id_service_categories]
      )
    end

    calendar_view = params[:view].presence || current_user.settings&.calendar_view || "default"

    customers = User.customers.order(updated_at: :desc).limit(50).to_a
    if Setting.get("limit_customer_access") == "1" && session[:role_slug] == Role::PROVIDER
      customers = customers.select { |customer| customer_access?(customer.id) }
    end
    customers = customers.map { |customer| EaRows.customer_row(customer) }

    backend_page_vars(page_title: helpers.lang("calendar"), active_menu: "appointments")

    script_vars(
      first_weekday: Setting.get("first_weekday"),
      company_working_plan: Setting.get("company_working_plan"),
      privileges: session_role.permissions,
      calendar_view: calendar_view,
      available_providers: available_providers,
      available_services: available_services,
      secretary_providers: secretary_provider_ids,
      edit_appointment: edit_appointment,
      google_sync_feature: Setting.get("google_sync_feature") == "1",
      customers: customers
    )

    script_vars(timezones: helpers.timezones)

    html_vars(
      calendar_view: calendar_view,
      available_languages: Localization.available_languages,
      available_providers: available_providers,
      available_services: available_services,
      secretary_providers: secretary_provider_ids,
      appointment_status_options: JSON.parse(Setting.get("appointment_status_options", "[]")),
      **%w[name email phone_number address city zip_code notes]
        .index_with { |field| Setting.get("require_#{field}") }
        .transform_keys { |field| "require_#{field}".to_sym }
    )

    render :index
  end

  # POST /calendar/save_appointment
  def save_appointment
    customer_data = permitted_hash(params[:customer_data], CUSTOMER_PERMIT)
    appointment_data = permitted_hash(params[:appointment_data], APPOINTMENT_PERMIT)
    notify_users = boolean_param(params.fetch(:notify_users, true))
    force_save = boolean_param(params.fetch(:force_save, false))

    raise ArgumentError, "Invalid appointment data." if appointment_data.blank?

    check_event_permissions!(appointment_data["id_users_provider"])
    return if performed?

    customer_id = nil
    if customer_data.present?
      unless can?(customer_data["id"].present? ? :add : :edit, :customers)
        raise ArgumentError, "You do not have the required permissions for this task."
      end

      customer_params = customer_data.slice(*BookingController::ALLOWED_CUSTOMER_FIELDS, "notes")
      existing = customer_params["id"].presence &&
                 User.customers.find_by(id: customer_params["id"])
      existing ||= customer_params["email"].presence &&
                   User.customers.find_by(email: customer_params["email"])
      customer = existing || User.new(role: Role.find_by!(slug: Role::CUSTOMER))
      customer.assign_attributes(customer_params.except("id"))
      customer.save!
      customer_id = customer.id
    end

    unless can?(appointment_data["id"].present? ? :add : :edit, :appointments)
      raise ArgumentError, "You do not have the required permissions for this task."
    end

    manage_mode = appointment_data["id"].present?
    appointment_data["id_users_customer"] ||= customer_id || customer_data&.dig("id")

    exclude_id = manage_mode ? appointment_data["id"].to_i : nil
    if Appointment.provider_conflict?(appointment_data["id_users_provider"],
                                      appointment_data["start_datetime"],
                                      appointment_data["end_datetime"], exclude_id) && !force_save
      return render json: { success: false, conflict: true,
                            message: helpers.lang("provider_has_conflicting_appointment") }
    end

    appointment = manage_mode ? Appointment.find(appointment_data["id"]) : Appointment.new
    appointment.assign_attributes(
      appointment_data.slice(*BookingController::ALLOWED_APPOINTMENT_FIELDS).except("id")
    )
    appointment.book_datetime ||= Time.now
    appointment.save!

    provider = appointment.provider
    customer = appointment.customer
    service = appointment.service
    settings = notification_settings

    Synchronization.appointment_saved(appointment, service, provider, customer, settings)
    if notify_users
      Notifications.appointment_saved(appointment, service, provider, customer, settings,
                                      manage_mode: manage_mode)
    end
    Webhooks.trigger(Webhooks::APPOINTMENT_SAVE, appointment)

    render json: { success: true }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /calendar/delete_appointment
  def delete_appointment
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:delete, :appointments)

    appointment = Appointment.find(params.require(:appointment_id))
    check_event_permissions!(appointment.id_users_provider)
    return if performed?

    cancellation_reason = params[:cancellation_reason].to_s
    notify_users = boolean_param(params.fetch(:notify_users, true))

    provider = appointment.provider
    customer = appointment.customer
    service = appointment.service
    settings = notification_settings

    appointment.destroy!

    if notify_users
      Notifications.appointment_deleted(appointment, service, provider, customer, settings,
                                        reason: cancellation_reason)
    end
    Synchronization.appointment_deleted(appointment, provider)
    Webhooks.trigger(Webhooks::APPOINTMENT_DELETE, appointment)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /calendar/save_unavailability
  def save_unavailability
    unavailability_data = permitted_hash(params[:unavailability], UNAVAILABILITY_PERMIT)
    raise ArgumentError, "Invalid unavailability data." if unavailability_data.blank?

    unless can?(unavailability_data["id"].present? ? :edit : :add, :appointments)
      raise ArgumentError, "You do not have the required permissions for this task."
    end

    check_event_permissions!(unavailability_data["id_users_provider"])
    return if performed?

    record = unavailability_data["id"].present? ? Appointment.find(unavailability_data["id"]) : Appointment.new
    record.assign_attributes(
      unavailability_data.slice("start_datetime", "end_datetime", "location", "notes", "id_users_provider")
    )
    record.is_unavailability = true
    record.book_datetime ||= Time.now
    record.save!

    Synchronization.unavailability_saved(record, record.provider)
    Webhooks.trigger(Webhooks::UNAVAILABILITY_SAVE, record)

    render json: { success: true, warnings: [] }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /calendar/delete_unavailability
  def delete_unavailability
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:delete, :appointments)

    record = Appointment.unavailabilities.find(params.require(:unavailability_id))
    check_event_permissions!(record.id_users_provider)
    return if performed?

    provider = record.provider
    record.destroy!

    Synchronization.unavailability_deleted(record, provider)
    Webhooks.trigger(Webhooks::UNAVAILABILITY_DELETE, record)

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

  def visible_providers
    providers = User.providers.joins(:provider_service_links).distinct
                    .order(:name, :email).includes(:services, :settings)
    case session[:role_slug]
    when Role::PROVIDER
      providers.where(id: session[:user_id])
    when Role::SECRETARY
      providers.where(id: secretary_provider_ids)
    else
      providers
    end
  end

  def calendar_events_response(appointments, unavailabilities, start_date, end_date)
    appointments = filter_events_by_role(appointments.includes(:provider, :service, :customer))
    unavailabilities = filter_events_by_role(unavailabilities.includes(:provider))

    {
      appointments: appointments.map do |appointment|
        EaRows.appointment_row(appointment).merge(
          "provider" => appointment.provider && EaRows.provider_row(appointment.provider),
          "service" => appointment.service && EaRows.service_row(appointment.service),
          "customer" => appointment.customer && EaRows.customer_row(appointment.customer)
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
    when Role::SECRETARY
      events.where(id_users_provider: secretary_provider_ids)
    else
      events
    end
  end

  CUSTOMER_PERMIT = (BookingController::ALLOWED_CUSTOMER_FIELDS + %w[notes]).map(&:to_sym).freeze
  APPOINTMENT_PERMIT = BookingController::ALLOWED_APPOINTMENT_FIELDS.map(&:to_sym).freeze
  UNAVAILABILITY_PERMIT = %i[id start_datetime end_datetime location notes id_users_provider].freeze
  EXCEPTION_PERMIT = [ :id, :startDate, :endDate, :startTime, :endTime, :start_date, :end_date,
                      :start_time, :end_time, { breaks: [ :start, :end ] } ].freeze

  def permitted_hash(value, allowed)
    value.is_a?(ActionController::Parameters) ? value.permit(*allowed).to_h : value
  end

  def boolean_param(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end

  def notification_settings
    company_color = Setting.get("company_color")
    {
      company_name: Setting.get("company_name"),
      company_link: Setting.get("company_link"),
      company_email: Setting.get("company_email"),
      company_color: company_color.present? && company_color != "#ffffff" ? company_color : nil,
      date_format: Setting.get("date_format"),
      time_format: Setting.get("time_format")
    }
  end
end
