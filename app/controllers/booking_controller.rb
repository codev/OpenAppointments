# Public booking wizard, port of EA's Booking controller.
class BookingController < ApplicationController
  layout "booking"

  ALLOWED_CUSTOMER_FIELDS = %w[id first_name last_name email phone_number address city state
                               zip_code timezone language custom_field_1 custom_field_2
                               custom_field_3 custom_field_4 custom_field_5].freeze
  ALLOWED_APPOINTMENT_FIELDS = %w[id start_datetime end_datetime location meeting_link notes
                                  color status is_unavailability id_users_provider
                                  id_users_customer id_services].freeze
  THEMES = %w[cosmo darkly default flatly litera lumen materia minty sketchy zephyr].freeze

  # Distinct name: per limit - unnamed limits in one controller share a cache key,
  # so the wizard's own availability polling would eat the register budget.
  rate_limit to: 15, within: 1.minute, only: :register, name: "register",
             with: -> { render json: { success: false, message: "Too many requests." }, status: :too_many_requests }
  # The availability lookups are unauthenticated and cheap to script; cap per-IP bursts.
  rate_limit to: 60, within: 1.minute, only: [ :get_available_hours, :get_unavailable_dates ], name: "availability",
             with: -> { render json: { success: false, message: "Too many requests." }, status: :too_many_requests }

  def reschedule
    html_vars(appointment_hash: params[:appointment_hash])
    index
  end

  def index
    if Setting.get("disable_booking") == "1"
      return render_booking_message(helpers.lang("booking_is_disabled"),
                                    Setting.get("disable_booking_message"), raw_text: true)
    end

    available_services = BookingPayloads.available_services
    available_providers = BookingPayloads.available_providers

    manage_mode = false
    appointment = provider_payload = customer_payload = nil
    customer_token = false

    appointment_hash = html_vars[:appointment_hash]
    if appointment_hash.present?
      record = Appointment.find_by(booking_hash: appointment_hash)
      unless record
        return render_booking_message(helpers.lang("appointment_not_found"),
                                      helpers.lang("appointment_does_not_exist_in_db"))
      end

      provider = record.provider
      timeout = Setting.get("book_advance_timeout", "0").to_i
      zone = Time.find_zone!(provider.timezone.presence || "UTC")
      appointment_start = zone.parse(record.start_datetime.strftime("%Y-%m-%d %H:%M:%S"))
      limit = Time.now + timeout * 60

      if appointment_start < limit
        message = helpers.lang("appointment_locked_message")
                         .sub("{$limit}", format("%02d:%02d", timeout / 60, timeout % 60))
        return render_booking_message(helpers.lang("appointment_locked"), message)
      end

      manage_mode = true
      appointment = appointment_payload(record)
      provider_payload = {
        "id" => provider.id, "first_name" => provider.first_name, "last_name" => provider.last_name,
        "services" => provider.services.map(&:id), "timezone" => provider.timezone
      }
      customer_payload = customer_fields(record.customer)
      customer_token = SecureRandom.hex(16)
      Rails.cache.write("customer-token-#{customer_token}", record.customer.id, expires_in: 10.minutes)
    end

    theme = params[:theme].to_s.gsub(/[^a-zA-Z0-9_\-]/, "")
    theme = Setting.get("theme", "default") if theme.blank?
    theme = "default" unless THEMES.include?(theme)

    company_color = Setting.get("company_color")

    script_vars(
      manage_mode: manage_mode,
      available_services: available_services,
      available_providers: available_providers,
      date_format: Setting.get("date_format"),
      time_format: Setting.get("time_format"),
      first_weekday: Setting.get("first_weekday"),
      display_cookie_notice: Setting.get("display_cookie_notice"),
      display_any_provider: Setting.get("display_any_provider"),
      future_booking_limit: Setting.get("future_booking_limit"),
      appointment_data: appointment,
      provider_data: provider_payload,
      customer_data: customer_payload,
      customer_token: customer_token,
      default_language: Setting.get("default_language"),
      default_timezone: Setting.get("default_timezone")
    )

    html_vars(
      available_services: available_services,
      available_providers: available_providers,
      theme: theme,
      company_name: Setting.get("company_name"),
      company_logo: Setting.get("company_logo"),
      company_color: company_color == "#ffffff" ? "" : company_color,
      date_format: Setting.get("date_format"),
      time_format: Setting.get("time_format"),
      first_weekday: Setting.get("first_weekday"),
      **field_display_vars,
      display_cookie_notice: Setting.get("display_cookie_notice"),
      cookie_notice_content: Setting.get("cookie_notice_content"),
      display_terms_and_conditions: Setting.get("display_terms_and_conditions"),
      terms_and_conditions_content: Setting.get("terms_and_conditions_content"),
      display_privacy_policy: Setting.get("display_privacy_policy"),
      privacy_policy_content: Setting.get("privacy_policy_content"),
      display_any_provider: Setting.get("display_any_provider"),
      display_login_button: Setting.get("display_login_button"),
      display_delete_personal_information: Setting.get("display_delete_personal_information"),
      legal_notice_url: Setting.get("legal_notice_url"),
      imprint_url: Setting.get("imprint_url"),
      google_analytics_code: Setting.get("google_analytics_code"),
      matomo_analytics_url: Setting.get("matomo_analytics_url"),
      matomo_analytics_site_id: Setting.get("matomo_analytics_site_id"),
      grouped_timezones: helpers.grouped_timezones,
      manage_mode: manage_mode,
      appointment_data: appointment,
      provider_data: provider_payload,
      customer_data: customer_payload
    )

    render :index
  end

  # POST /booking/register
  def register
    return head :forbidden if Setting.get("disable_booking") == "1"

    post_data = params[:post_data]
    if post_data.is_a?(ActionController::Parameters)
      post_data = post_data.permit(:manage_mode,
                                   appointment: ALLOWED_APPOINTMENT_FIELDS.map(&:to_sym),
                                   customer: ALLOWED_CUSTOMER_FIELDS.map(&:to_sym)).to_h
    end
    raise ArgumentError, "Invalid request data format." unless post_data.is_a?(Hash)

    appointment_params = post_data["appointment"]
    customer_params = post_data["customer"]
    manage_mode = ActiveModel::Type::Boolean.new.cast(post_data["manage_mode"]) || false

    raise ArgumentError, "Invalid appointment data." if appointment_params.blank?
    raise ArgumentError, "Invalid customer data." if customer_params.blank?

    if customer_params["email"].present? && !customer_params["email"].match?(URI::MailTo::EMAIL_REGEXP)
      raise ArgumentError, "Invalid email address format."
    end

    customer_params = customer_params.slice(*ALLOWED_CUSTOMER_FIELDS)
    appointment_params = appointment_params.slice(*ALLOWED_APPOINTMENT_FIELDS)

    %w[address city zip_code notes phone_number].each { |field| customer_params[field] ||= "" }

    provider_id = check_datetime_availability(appointment_params, manage_mode)
    raise ArgumentError, helpers.lang("requested_hour_is_unavailable") unless provider_id

    appointment_params["id_users_provider"] = provider_id
    provider = User.providers.find(provider_id)
    service = Service.find(appointment_params["id_services"])

    if AltchaChallenge.enabled? && !AltchaChallenge.verify(params[:altcha_payload])
      return render json: { altcha_verification: false }
    end

    existing_customer = User.customers.find_by(email: customer_params["email"]) if customer_params["email"].present?
    if existing_customer
      conflict = Appointment.where(id_users_customer: existing_customer.id)
                            .where("start_datetime <= ? AND end_datetime >= ?",
                                   appointment_params["start_datetime"], end_datetime_for(appointment_params, service))
      conflict = conflict.where.not(id: appointment_params["id"]) if manage_mode
      raise ArgumentError, helpers.lang("customer_is_already_booked") if conflict.exists?
    end

    save_consents(customer_params)

    customer = existing_customer || User.new(role: Role.find_by!(slug: Role::CUSTOMER))
    customer.assign_attributes(customer_params.except("id", "timezone", "language")
                                              .merge("timezone" => customer_params["timezone"].presence || "UTC"))
    customer.language = session[:language] || Setting.get("default_language", "english")
    customer.last_name = customer.first_name if customer.last_name.blank?
    customer.save!

    appointment = manage_mode ? Appointment.find(appointment_params["id"]) : Appointment.new
    appointment.assign_attributes(
      start_datetime: appointment_params["start_datetime"],
      end_datetime: end_datetime_for(appointment_params, service),
      location: appointment_params["location"].presence || service.location,
      notes: appointment_params["notes"],
      customer: customer,
      provider: provider,
      service: service,
      is_unavailability: false,
      color: service.color,
      status: JSON.parse(Setting.get("appointment_status_options", "[]")).first,
      book_datetime: appointment.book_datetime || Time.now
    )
    appointment.save!

    settings = notification_settings

    Synchronization.appointment_saved(appointment, service, provider, customer, settings)
    Notifications.appointment_saved(appointment, service, provider, customer, settings, manage_mode: manage_mode)
    Webhooks.trigger(Webhooks::APPOINTMENT_SAVE, appointment)

    render json: { appointment_id: appointment.id, appointment_hash: appointment.booking_hash }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /booking/get_available_hours
  def get_available_hours
    return head :forbidden if Setting.get("disable_booking") == "1"

    provider_id = params[:provider_id]
    service_id = params[:service_id]
    selected_date = params[:selected_date]
    return render json: [] if provider_id.blank?

    manage_mode = params[:manage_mode].to_s == "1"
    exclude_appointment_id = manage_mode ? params[:appointment_id].presence : nil

    service = Service.find(service_id)
    engine = Availability::Engine.new

    if provider_id == BookingPayloads::ANY_PROVIDER
      hours = BookingPayloads.providers_for_service(service.id).flat_map do |provider|
        engine.available_hours(selected_date, service, provider, exclude_appointment_id: exclude_appointment_id)
      end
      render json: hours.uniq.sort
    else
      provider = User.providers.find(provider_id)
      render json: engine.available_hours(selected_date, service, provider,
                                          exclude_appointment_id: exclude_appointment_id)
    end
  rescue StandardError => e
    json_exception(e)
  end

  # GET /booking/get_unavailable_dates
  def get_unavailable_dates
    return head :forbidden if Setting.get("disable_booking") == "1"

    provider_id = params[:provider_id]
    service_id = params[:service_id]
    manage_mode = ActiveModel::Type::Boolean.new.cast(params[:manage_mode]) || false
    exclude_appointment_id = manage_mode ? params[:appointment_id].presence : nil

    selected_date = Date.parse(CGI.unescape(params[:selected_date].to_s))
    days_in_month = Date.new(selected_date.year, selected_date.month, -1).day

    service = Service.find(service_id)
    providers =
      if provider_id == BookingPayloads::ANY_PROVIDER
        BookingPayloads.providers_for_service(service.id).to_a
      else
        [ User.providers.find(provider_id) ]
      end

    engine = Availability::Engine.new
    today = Date.today
    unavailable_dates = []

    (1..days_in_month).each do |day|
      current_date = Date.new(selected_date.year, selected_date.month, day)

      if current_date < today
        unavailable_dates << current_date.strftime("%Y-%m-%d")
        next
      end

      available = providers.any? do |provider|
        engine.available_hours(current_date.strftime("%Y-%m-%d"), service, provider,
                               exclude_appointment_id: exclude_appointment_id).any?
      end

      unavailable_dates << current_date.strftime("%Y-%m-%d") unless available
    end

    if unavailable_dates.length == days_in_month
      render json: { is_month_unavailable: true }
    else
      render json: unavailable_dates
    end
  rescue StandardError => e
    json_exception(e)
  end

  private

  def render_booking_message(title, text, raw_text: false)
    html_vars(
      show_message: true,
      page_title: "#{helpers.lang('page_title')} #{Setting.get('company_name')}",
      message_title: title,
      message_text: text,
      message_icon: helpers.image_path("error.png"),
      google_analytics_code: Setting.get("google_analytics_code"),
      matomo_analytics_url: Setting.get("matomo_analytics_url"),
      matomo_analytics_site_id: Setting.get("matomo_analytics_site_id"),
      display_login_button: Setting.get("display_login_button"),
      legal_notice_url: Setting.get("legal_notice_url"),
      imprint_url: Setting.get("imprint_url"),
      message_is_html: raw_text
    )
    render "booking/message", layout: "message"
  end

  def check_datetime_availability(appointment_params, manage_mode)
    start = Time.parse(appointment_params["start_datetime"])
    date = start.strftime("%Y-%m-%d")
    hour = start.strftime("%H:%M")
    service_id = appointment_params["id_services"]
    engine = Availability::Engine.new

    if appointment_params["id_users_provider"] == BookingPayloads::ANY_PROVIDER
      return search_any_provider(service_id, date, hour)
    end

    service = Service.find(service_id)
    provider = User.providers.find(appointment_params["id_users_provider"])
    exclude_appointment_id = manage_mode ? appointment_params["id"] : nil

    hours = engine.available_hours(date, service, provider, exclude_appointment_id: exclude_appointment_id)
    hours.include?(hour) ? provider.id : nil
  end

  def search_any_provider(service_id, date, hour = nil)
    service = Service.find(service_id)
    engine = Availability::Engine.new
    best_provider_id = nil
    max_hours = 0

    BookingPayloads.providers_for_service(service_id).each do |provider|
      hours = engine.available_hours(date, service, provider)
      if hours.length > max_hours && (hour.blank? || hours.include?(hour))
        best_provider_id = provider.id
        max_hours = hours.length
      end
    end

    best_provider_id
  end

  def end_datetime_for(appointment_params, service)
    start = Time.parse(appointment_params["start_datetime"])
    (start + service.duration.to_i * 60).strftime("%Y-%m-%d %H:%M:%S")
  end

  def save_consents(customer_params)
    consent = {
      first_name: customer_params["first_name"] || "-",
      last_name: customer_params["last_name"] || "-",
      email: customer_params["email"] || "-",
      ip: request.remote_ip
    }
    Consent.create!(consent.merge(type: "terms-and-conditions")) if Setting.get("display_terms_and_conditions") == "1"
    Consent.create!(consent.merge(type: "privacy-policy")) if Setting.get("display_privacy_policy") == "1"
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

  # EA row shape for script_vars appointment_data (naive Y-m-d H:i:s strings).
  def appointment_payload(record)
    {
      "id" => record.id,
      "book_datetime" => record.book_datetime&.strftime("%Y-%m-%d %H:%M:%S"),
      "start_datetime" => record.start_datetime&.strftime("%Y-%m-%d %H:%M:%S"),
      "end_datetime" => record.end_datetime&.strftime("%Y-%m-%d %H:%M:%S"),
      "location" => record.location, "meeting_link" => record.meeting_link,
      "notes" => record.notes, "hash" => record.booking_hash, "color" => record.color,
      "status" => record.status, "is_unavailability" => record.is_unavailability,
      "id_users_provider" => record.id_users_provider,
      "id_users_customer" => record.id_users_customer, "id_services" => record.id_services
    }
  end

  def customer_fields(customer)
    BookingController::ALLOWED_CUSTOMER_FIELDS.index_with { |field| customer.public_send(field) }
  end

  def field_display_vars
    fields = %w[first_name last_name email phone_number address city zip_code notes]
    fields.flat_map { |field|
      [ [ "display_#{field}".to_sym, Setting.get("display_#{field}") ],
       [ "require_#{field}".to_sym, Setting.get("require_#{field}") ] ]
    }.to_h
  end
end
