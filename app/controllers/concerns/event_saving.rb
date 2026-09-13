# Saving, cancelling and deleting appointments and unavailabilities, shared by
# the calendar JSON endpoints (drag and resize) and the event forms. Methods
# raise ArgumentError for permission and validation problems and
# EventSaving::Conflict when the provider already has an appointment.
module EventSaving
  extend ActiveSupport::Concern

  class Conflict < StandardError; end
  # Another provider's event (EA answers 403 rather than an error payload).
  class Forbidden < StandardError; end

  CUSTOMER_FIELDS = (BookingController::ALLOWED_CUSTOMER_FIELDS + %w[notes]).freeze
  APPOINTMENT_FIELDS = BookingController::ALLOWED_APPOINTMENT_FIELDS.freeze
  UNAVAILABILITY_FIELDS = %w[id start_datetime end_datetime location notes id_users_provider].freeze

  private

  # Returns { appointment:, skipped: }.
  def store_appointment(appointment_data, customer_data, repeat, notify_users:, force_save:)
    raise ArgumentError, "Invalid appointment data." if appointment_data.blank?

    ensure_event_permission!(appointment_data["id_users_provider"])
    customer_id = store_customer(customer_data)

    manage_mode = appointment_data["id"].present?
    unless can?(manage_mode ? :edit : :add, :appointments)
      raise ArgumentError, "You do not have the required permissions for this task."
    end
    appointment_data["id_users_customer"] ||= customer_id || customer_data&.dig("id")

    unless ServiceProviderLink.exists?(id_users: appointment_data["id_users_provider"], id_services: appointment_data["id_services"])
      raise ArgumentError, helpers.lang("provider_does_not_offer_service")
    end

    exclude_id = manage_mode ? appointment_data["id"].to_i : nil
    if !force_save && Appointment.provider_conflict?(appointment_data["id_users_provider"],
                                                     appointment_data["start_datetime"],
                                                     appointment_data["end_datetime"], exclude_id)
      raise Conflict, helpers.lang("provider_has_conflicting_appointment")
    end

    appointment = manage_mode ? Appointment.find(appointment_data["id"]) : Appointment.new
    previous_status_id = appointment.status_id
    appointment.assign_attributes(appointment_data.slice(*APPOINTMENT_FIELDS).except("id"))
    appointment.book_datetime ||= Time.now
    appointment.save!

    skipped = []
    if repeat.present? && repeat["rule"].present? && !manage_mode
      result = AppointmentSeries.start_from(appointment, repeat, created_by: session[:user_id])
      result[:series].announce(created: result[:rows])
      skipped = result[:skipped]
    end

    settings = notification_settings
    Synchronization.appointment_saved(appointment, appointment.service, appointment.provider, appointment.customer, settings)
    if notify_users
      Notifications.appointment_saved(appointment, appointment.service, appointment.provider, appointment.customer,
                                      settings, manage_mode: manage_mode, previous_status_id: previous_status_id)
    end
    Webhooks.trigger(Webhooks::APPOINTMENT_SAVE, appointment)
    { appointment: appointment, skipped: skipped }
  end

  # The appointment's customer: an existing record by id or email, else a new one.
  def store_customer(customer_data)
    return nil if customer_data.blank?

    unless can?(customer_data["id"].present? ? :edit : :add, :customers)
      raise ArgumentError, "You do not have the required permissions for this task."
    end

    customer_params = customer_data.slice(*CUSTOMER_FIELDS)
    existing = customer_params["id"].presence && User.customers.find_by(id: customer_params["id"])
    existing ||= customer_params["email"].presence && User.customers.find_by(email: customer_params["email"])
    customer = existing || User.new(role: Role.find_by!(slug: Role::CUSTOMER))
    customer.assign_attributes(customer_params.except("id"))
    customer.save!
    customer.id
  end

  # kind: "cancel" keeps the row with the cancelled status, "delete" destroys it.
  def remove_appointment_record(appointment, kind:, reason:, notify_users:)
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:delete, :appointments)

    ensure_event_permission!(appointment.id_users_provider)
    provider = appointment.provider
    customer = appointment.customer
    service = appointment.service

    kind == "cancel" ? appointment.cancel!(reason: reason) : appointment.destroy!
    appointment.series&.forget(appointment.occurrence_at)

    if notify_users
      Notifications.appointment_deleted(appointment, service, provider, customer, notification_settings, reason: reason)
    end
    Synchronization.appointment_deleted(appointment, provider)
    Webhooks.trigger(Webhooks::APPOINTMENT_DELETE, appointment)
  end

  def store_unavailability(unavailability_data)
    raise ArgumentError, "Invalid unavailability data." if unavailability_data.blank?

    unless can?(unavailability_data["id"].present? ? :edit : :add, :appointments)
      raise ArgumentError, "You do not have the required permissions for this task."
    end
    ensure_event_permission!(unavailability_data["id_users_provider"])

    record = unavailability_data["id"].present? ? Appointment.find(unavailability_data["id"]) : Appointment.new
    record.assign_attributes(unavailability_data.slice("start_datetime", "end_datetime", "location", "notes", "id_users_provider"))
    record.is_unavailability = true
    record.book_datetime ||= Time.now
    record.save!

    Synchronization.unavailability_saved(record, record.provider)
    Webhooks.trigger(Webhooks::UNAVAILABILITY_SAVE, record)
    record
  end

  def remove_unavailability(record)
    raise ArgumentError, "You do not have the required permissions for this task." if cannot?(:delete, :appointments)

    ensure_event_permission!(record.id_users_provider)
    provider = record.provider
    record.destroy!
    Synchronization.unavailability_deleted(record, provider)
    Webhooks.trigger(Webhooks::UNAVAILABILITY_DELETE, record)
  end

  # EA Calendar::check_event_permissions as an exception.
  def ensure_event_permission!(provider_id)
    allowed = case session[:role_slug]
    when Role::ASSISTANT then assistant_provider_ids.include?(provider_id.to_i)
    when Role::PROVIDER then session[:user_id].to_i == provider_id.to_i
    else true
    end
    raise Forbidden, "You do not have the required permissions for this task." unless allowed
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
