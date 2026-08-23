# Appointments page (one day column per provider, the EA "table" view) and the
# appointment dialog forms used by both calendar pages.
class AppointmentsController < ApplicationController
  include CalendarPage
  include EventForm

  def index
    render_calendar_page(page_title: "appointments", active_menu: "appointments")
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
