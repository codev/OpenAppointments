# Appointments page (one day column per provider, the EA "table" view, rendered
# server side from the URL's date and filters) and the appointment dialog forms
# used by both calendar pages.
class AppointmentsController < ApplicationController
  include CalendarPage
  include EventForm

  DAY_COUNTS = [ 1, 3 ].freeze

  # GET /appointments?date=&days=&provider=&service=&statuses[]=
  def index
    return unless require_backend_page!(:appointments)

    @date = Date.parse(params[:date].to_s) rescue Date.current
    @days = DAY_COUNTS.include?(params[:days].to_i) ? params[:days].to_i : 1
    @provider_id = params[:provider].to_i
    @service_id = params[:service].to_i
    @statuses = AppointmentStatus.rows
    @selected_statuses = params.key?(:statuses) ? Array(params[:statuses]) : default_statuses
    @providers = visible_providers.to_a
    @services = Service.available.joins(:provider_links).distinct.order(:name).to_a
    @columns = build_columns
    backend_page_vars(page_title: helpers.lang("appointments"), active_menu: "appointments")
    script_vars(edit_appointment: edit_appointment_var, first_weekday: Setting.get("first_weekday"))
    html_vars(appointment_statuses: @statuses)
    render :index
  end

  # GET /appointments/new?start=&end=&provider_id=&service_id=
  def new
    head :forbidden and return if cannot?(:add, :appointments)

    @appointment = Appointment.new(start_datetime: params[:start].presence, end_datetime: params[:end].presence,
                                   id_users_provider: params[:provider_id].presence, id_services: params[:service_id].presence)
    @customer = User.new
    load_form_data
    default_times
    render_form :form
  end

  # GET /appointments/:id/edit
  def edit
    head :forbidden and return if cannot?(:edit, :appointments)

    @appointment = Appointment.appointments.find(params[:id])
    ensure_event_permission!(@appointment.id_users_provider)
    @customer = @appointment.customer || User.new
    load_form_data
    render_form :form
  end

  # POST /appointments, PATCH /appointments/:id
  def create = save
  def update = save

  # GET /appointments/:id/remove?kind=cancel|delete - the reason and notify form.
  def remove_form
    head :forbidden and return if cannot?(:delete, :appointments)

    @appointment = Appointment.appointments.find(params[:id])
    ensure_event_permission!(@appointment.id_users_provider)
    @kind = params[:kind] == "delete" ? "delete" : "cancel"
    render_form :remove
  end

  # POST /appointments/:id/remove
  def remove
    appointment = Appointment.appointments.find(params[:id])
    kind = params[:kind] == "delete" ? "delete" : "cancel"
    remove_appointment_record(appointment, kind: kind, reason: params[:cancellation_reason].to_s,
                              notify_users: boolean_param(params.fetch(:notify_users, true)))
    render_saved(nil)
  rescue ArgumentError => e
    @appointment = appointment
    @kind = kind
    @error = e.message
    render_form :remove, status: :unprocessable_entity
  end

  private

  def default_statuses
    @statuses.reject { |status| %w[cancelled rescheduled].include?(status["kind"]) }.map { |status| status["name"] }
  end

  def edit_appointment_var
    return nil if params[:appointment_hash].blank?

    record = Appointment.find_by(booking_hash: params[:appointment_hash].to_s)
    record && EaRows.appointment_row(record)
  end

  # [{ date:, days: [ProviderDay], not_working: [providers] }] for each shown date.
  def build_columns
    dates = (0...@days).map { |offset| @date + offset }
    providers = @provider_id.positive? ? @providers.select { |p| p.id == @provider_id } : @providers
    range = dates.first.beginning_of_day..dates.last.end_of_day
    appointments = role_events(Appointment.appointments.where(start_datetime: range).includes(:service, :customer, :appointment_status))
                   .select { |a| @selected_statuses.include?(a.status) }
                   .select { |a| @service_id.zero? || a.id_services == @service_id }
    unavailabilities = role_events(Appointment.unavailabilities.where("start_datetime <= ? AND end_datetime >= ?", range.end, range.begin))
    blocked = BlockedPeriod.for_period(dates.first, dates.last).to_a

    dates.map do |date|
      days = providers.map do |provider|
        ProviderDay.new(provider, date,
                        appointments: appointments.select { |a| a.id_users_provider == provider.id && a.start_datetime.to_date == date },
                        unavailabilities: unavailabilities.select { |u| u.id_users_provider == provider.id && u.start_datetime.to_date <= date && u.end_datetime.to_date >= date },
                        blocked_periods: blocked.select { |b| b.start_datetime.to_date <= date && b.end_datetime.to_date >= date })
      end
      { date: date, days: days.select(&:working?), not_working: days.reject(&:working?).map(&:provider) }
    end
  end

  def role_events(scope)
    case session[:role_slug]
    when Role::PROVIDER then scope.where(id_users_provider: session[:user_id])
    when Role::ASSISTANT then scope.where(id_users_provider: assistant_provider_ids)
    else scope
    end.to_a
  end

  def save
    data = appointment_params
    data["id"] = params[:id] if params[:id].present?
    data["start_datetime"] = parse_event_datetime(data["start_datetime"])
    data["end_datetime"] = parse_event_datetime(data["end_datetime"])
    data["is_unavailability"] = 0
    customer = customer_params
    customer = nil if customer.values_at("id", "name", "email").all?(&:blank?)

    result = store_appointment(data, customer, repeat_params,
                               notify_users: boolean_param(params.fetch(:notify_users, true)),
                               force_save: boolean_param(params.fetch(:force_save, false)))
    render_saved(helpers.lang("appointment_saved"), skipped: result[:skipped])
  rescue EventSaving::Conflict => e
    reload_form(data, customer)
    @error = e.message
    @force_save = true
    render_form :form, status: :unprocessable_entity
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    reload_form(data, customer)
    @error = e.message
    render_form :form, status: :unprocessable_entity
  end

  def appointment_params
    params.require(:appointment).permit(*EventSaving::APPOINTMENT_FIELDS.map(&:to_sym)).to_h.except("id")
  end

  def customer_params
    params.fetch(:customer, {}).permit(*EventSaving::CUSTOMER_FIELDS.map(&:to_sym)).to_h
  end

  def repeat_params
    params.fetch(:repeat, {}).permit(:rule, :ends, :ends_on, :count).to_h
  end

  # Rebuild the form objects from the posted values after an error.
  def reload_form(data, customer)
    @appointment = params[:id].present? ? Appointment.find(params[:id]) : Appointment.new
    @appointment.assign_attributes(data.slice(*EventSaving::APPOINTMENT_FIELDS).except("id", "is_unavailability"))
    @customer = User.new(customer.to_h.except("id"))
    @customer.id = customer["id"].presence if customer
    load_form_data
  end

  # As the jQuery dialog: the next quarter hour, for the duration of the
  # chosen (else the first offered) service.
  def default_times
    return if @appointment.start_datetime.present?

    start = Time.zone.now
    minutes = start.min
    start = minutes.zero? ? start : start.change(min: 0) + ((minutes / 15) + 1) * 15.minutes
    duration = (@appointment.service || @services.first)&.duration || 60
    @appointment.start_datetime = start
    @appointment.end_datetime = start + duration.minutes
  end

  def load_form_data
    @providers = providers_for_form.to_a
    service_ids = @providers.flat_map { |provider| provider.services.map(&:id) }.uniq
    @services = Service.available.where(id: service_ids).includes(:category).order(:name).to_a
    @statuses = AppointmentStatus.rows
    @customers = User.customers.order(updated_at: :desc).limit(50).to_a
    if Setting.get("limit_customer_access") == "1" && session[:role_slug] == Role::PROVIDER
      @customers = @customers.select { |customer| customer_access?(customer.id) }
    end
    html_vars(**field_display_flags)
  end
end
