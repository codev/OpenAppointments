# Public booking wizard, port of EA's Booking controller.
class BookingController < ApplicationController
  include EmbeddableFrame
  layout "booking"

  ALLOWED_CUSTOMER_FIELDS = %w[id name email phone_number address city state
                               zip_code timezone language custom_field_1 custom_field_2
                               custom_field_3 custom_field_4 custom_field_5].freeze
  ALLOWED_APPOINTMENT_FIELDS = %w[id start_datetime end_datetime location meeting_link notes
                                  color status is_unavailability id_users_provider
                                  id_users_customer id_services].freeze
  THEMES = %w[brutalism coder fruit material nice outline solid].freeze

  rate_limit to: 15, within: 1.minute, only: :register,
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

    additions = BookingPayloads.slug_additions(
      params[:service], params[:provider],
      known_service_ids: available_services.map { |row| row["id"] },
      known_provider_ids: available_providers.map { |row| row["id"] }
    )
    available_services += additions[:services]
    available_providers += additions[:providers]

    manage_mode = false
    appointment = provider_payload = customer_payload = nil
    customer_token = false

    appointment_hash = html_vars[:appointment_hash]
    if appointment_hash.present?
      record = Appointment.find_by(booking_hash: appointment_hash)
      if !record || record.frees_slot? || BookingWindows.past?(record)
        return render_booking_message(helpers.lang("appointment_not_found"),
                                      helpers.lang("appointment_does_not_exist_in_db"))
      end
      return render_late_cancel(record) if BookingWindows.late?(record)

      manage_mode = true
      appointment, provider_payload = manage_payloads(record, available_services, available_providers)
      customer_payload = customer_fields(record.customer)
      customer_token = SecureRandom.hex(16)
      Rails.cache.write("customer-token-#{customer_token}", record.customer.id, expires_in: 10.minutes)
    end

    base_index_vars(available_services, available_providers, manage_mode, appointment: appointment,
                    provider_payload: provider_payload, customer_payload: customer_payload,
                    customer_token: customer_token)
    resolve_wizard_state(available_services, available_providers, manage_mode)
    render :index
  end

  # POST /booking/confirm - the customer details post here; the confirmation
  # step renders with everything in hidden fields (customer data stays out of URLs).
  # Without a chosen slot the page shows the step the state reaches instead.
  def confirm
    return head :forbidden if Setting.get("disable_booking") == "1"

    index_vars_for_confirm
    @customer = customer_form_params
    if @reachable.include?("info")
      @error, @invalid_fields = customer_error(@customer) if params[:back].blank?
      @step = params[:back].present? || @error ? "info" : "final"
    else
      @step = @reachable.last
    end
    render :index
  end

  # POST /booking/waitlist: the time step's waiting list signup, rendered back
  # into the same step with the outcome.
  def waitlist
    return head :forbidden unless Setting.get("waitlist_enabled") == "1"

    index_vars_for_confirm
    return head :bad_request unless @reachable.include?("time")

    @step = "time"
    signup = params.fetch(:waitlist, {}).permit(:name, :email, :phone).to_h
    @waitlist_notice, @waitlist_alert = waitlist_signup(signup)
    render :index
  end

  # GET /booking/waitlist/leave/:token, the link in every waiting list notice.
  def leave_waitlist
    entry = WaitlistEntry.find_by(unsubscribe_token: params[:token].to_s)
    entry&.destroy!
    render_booking_message(helpers.lang("waitlist"), helpers.lang(entry ? "waitlist_left" : "waitlist_link_invalid"),
                           icon: entry ? "success.png" : "error.png")
  end

  # POST /booking/register
  def register
    return head :forbidden if Setting.get("disable_booking") == "1"

    post_data = params[:post_data]
    if post_data.blank? && params[:appointment].present?
      post_data = {
        "manage_mode" => params[:manage_mode],
        "appointment_hash" => params[:appointment_hash],
        "appointment" => params.require(:appointment).permit(*ALLOWED_APPOINTMENT_FIELDS.map(&:to_sym)).to_h,
        "customer" => params.require(:customer).permit(*ALLOWED_CUSTOMER_FIELDS.map(&:to_sym)).to_h
      }
    end
    if post_data.is_a?(ActionController::Parameters)
      post_data = post_data.permit(:manage_mode, :appointment_hash,
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

    if Setting.get("require_phone_or_email", "1") == "1" &&
       customer_params["email"].blank? && customer_params["phone_number"].blank?
      raise ArgumentError, helpers.lang("phone_or_email_required")
    end

    %w[address city zip_code phone_number].each { |field| customer_params[field] ||= "" }

    # A reschedule books a new row and marks the original Rescheduled.
    original = manage_mode ? reschedule_original(appointment_params["id"], post_data["appointment_hash"]) : nil
    appointment_params["id"] = original&.id

    provider_id = check_datetime_availability(appointment_params, manage_mode)
    raise ArgumentError, helpers.lang("requested_hour_is_unavailable") unless provider_id

    appointment_params["id_users_provider"] = provider_id
    provider = User.providers.find(provider_id)
    service = Service.find(appointment_params["id_services"])

    if AltchaChallenge.enabled? && !AltchaChallenge.verify(params[:altcha_payload])
      return form_post? ? register_failed(helpers.lang("altcha_verification_failed")) : render(json: { altcha_verification: false })
    end

    if TurnstileChallenge.enabled? && !TurnstileChallenge.verify(params[:cf_turnstile_response], request.remote_ip)
      return form_post? ? register_failed(helpers.lang("turnstile_verification_failed")) : render(json: { turnstile_verification: false })
    end

    existing_customer = User.customer_for_booking(email: customer_params["email"], phone: customer_params["phone_number"],
                                                  name: customer_params["name"])
    # A reschedule keeps the appointment's customer unless the details now belong to another record.
    existing_customer ||= original.customer if original
    if existing_customer
      conflict = Appointment.active.where(id_users_customer: existing_customer.id)
                            .where("start_datetime < ? AND end_datetime > ?",
                                   end_datetime_for(appointment_params, service), appointment_params["start_datetime"])
      conflict = conflict.where.not(id: original.id) if original
      raise ArgumentError, helpers.lang("customer_is_already_booked") if conflict.exists?
    end

    save_consents(customer_params)

    customer = existing_customer || User.new(role: Role.find_by!(slug: Role::CUSTOMER))
    timezone = customer_params["timezone"].presence || (customer.new_record? ? provider.effective_timezone : customer.timezone)
    details = customer_params.except("id", "timezone", "language")
    # A booking only fills in what an existing record lacks, so nobody who
    # knows a customer's name and phone can take over their email, or wipe it.
    details = details.compact_blank.select { |field, _| customer[field].blank? } if customer.persisted?
    customer.assign_attributes(details.merge("timezone" => timezone))
    customer.language = session[:language] || Setting.get("default_language", "english")
    customer.save!

    appointment = Appointment.new(series_id: original&.series_id, occurrence_at: original&.occurrence_at)
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
      appointment_status: AppointmentStatus.of("booked"),
      book_datetime: Time.now
    )
    Appointment.transaction do
      appointment.save!
      original&.update!(appointment_status: AppointmentStatus.of("rescheduled"), rescheduled_to: appointment)
    end

    settings = notification_settings

    Synchronization.appointment_deleted(original, provider) if original
    Synchronization.appointment_saved(appointment, service, provider, customer, settings)
    Notifications.appointment_saved(appointment, service, provider, customer, settings, manage_mode: manage_mode)
    Webhooks.trigger(Webhooks::APPOINTMENT_SAVE, appointment)
    WaitlistEntry.where(email: customer.email, service_id: service.id).delete_all if customer.email.present?

    if form_post?
      redirect_to booking_confirmation_path(appointment_hash: appointment.booking_hash)
    else
      render json: { appointment_id: appointment.id, appointment_hash: appointment.booking_hash }
    end
  rescue ArgumentError => e
    form_post? ? register_failed(e.message) : json_exception(e, status: :ok)
  end

  private

  def form_post? = params[:form].present?

  def base_index_vars(available_services, available_providers, manage_mode, appointment: nil,
                      provider_payload: nil, customer_payload: nil, customer_token: false)
    theme = params[:theme].to_s.gsub(/[^a-zA-Z0-9_\-]/, "")
    theme = Setting.get("theme", "default") if theme.blank?
    theme = "nice" unless THEMES.include?(theme)

    company_color = Setting.get("company_color")

    first_step = params[:first].presence ||
                 (Setting.get("booking_provider_first", "0") == "1" ? "provider" : "service")
    first_step = "service" unless %w[service provider].include?(first_step)

    display_mode = Setting.get("booking_display_mode", "dropdown")
    display_mode = "dropdown" unless %w[dropdown cards].include?(display_mode)

    available_categories = []
    if display_mode == "cards"
      available_categories = BookingPayloads.available_categories
      # Categories of injected (private/hidden) services so their cards render.
      missing_category_ids = available_services.filter_map { |row| row["service_category_id"] }.uniq -
                             available_categories.map { |row| row["id"] }
      available_categories += ServiceCategory.where(id: missing_category_ids).with_attached_picture
                                             .display_order
                                             .map { |category| BookingPayloads.category_payload(category) }
    end

    # utils/ui.js reads these for the calendar; the wizard itself is server rendered.
    script_vars(
      date_format: Setting.get("date_format"),
      time_format: Setting.get("time_format"),
      first_weekday: Setting.get("first_weekday")
    )

    html_vars(
      first_step: first_step,
      display_mode: display_mode,
      available_categories: available_categories,
      available_services: available_services,
      available_providers: available_providers,
      theme: theme,
      company_name: Setting.get("company_name"),
      company_logo: CompanyLogo.path,
      company_color: company_color == "#ffffff" ? "" : company_color,
      date_format: Setting.get("date_format"),
      time_format: Setting.get("time_format"),
      first_weekday: Setting.get("first_weekday"),
      **field_display_vars,
      display_booking_notice_time_step: Setting.get("display_booking_notice_time_step"),
      display_booking_notice_info_step: Setting.get("display_booking_notice_info_step"),
      booking_notice_content: Setting.get("booking_notice_content"),
      fully_booked_notice_content: Setting.get("fully_booked_notice_content"),
      display_waitlist: Setting.get("waitlist_enabled"),
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
      customer_data: customer_payload,
      customer_token: customer_token
    )
  end

  STEPS = %w[first second time info final].freeze

  # The wizard's URL state: which step shows and what is chosen. The step never
  # runs ahead of its prerequisites; slug deep links preselect and lock.
  def resolve_wizard_state(available_services, available_providers, manage_mode)
    slugged_service = params[:service].present? &&
                      available_services.find { |row| row["booking_slug"] == params[:service] }
    slugged_provider = params[:provider].present? &&
                       available_providers.find { |row| row["booking_slug"] == params[:provider] }

    @service_id = (params[:service_id].presence || (slugged_service ? slugged_service["id"] : nil) ||
                   (manage_mode ? html_vars[:appointment_data]["id_services"] : nil)).to_i
    @provider_id = params[:provider_id].presence ||
                   (slugged_provider ? slugged_provider["id"].to_s : nil) ||
                   (manage_mode ? html_vars[:provider_data]["id"].to_s : nil)
    @service_id = 0 unless available_services.any? { |row| row["id"] == @service_id }
    unless @provider_id == BookingPayloads::ANY_PROVIDER ||
           available_providers.any? { |row| row["id"].to_s == @provider_id.to_s }
      @provider_id = nil
    end
    # The pair must actually match.
    if @service_id.positive? && @provider_id.present? && @provider_id != BookingPayloads::ANY_PROVIDER
      provider = available_providers.find { |row| row["id"].to_s == @provider_id.to_s }
      @provider_id = nil unless provider && provider["services"].include?(@service_id)
    end
    @date = params[:date].to_s[/\A\d{4}-\d{2}-\d{2}\z/]
    @time = params[:time].to_s[/\A\d{2}:\d{2}\z/]
    @timezone = params[:timezone].presence if params[:timezone].present? && Time.find_zone(params[:timezone])

    first_kind = html_vars[:first_step] # "service" or "provider"
    chosen = { "service" => @service_id.positive?, "provider" => @provider_id.present? }
    @reachable = [ "first" ]
    @reachable << "second" if chosen[first_kind]
    @reachable << "time" if chosen.values.all?
    @reachable << "info" if chosen.values.all? && @date && @time

    requested = STEPS.include?(params[:step]) ? params[:step] : nil
    requested ||= manage_mode && chosen.values.all? ? "time" : "first"
    @step = @reachable.include?(requested) ? requested : @reachable.last

    if @step == "time"
      service = Service.find(@service_id)
      exclude = manage_mode ? html_vars[:appointment_data]["id"] : nil
      @window = BookingWindow.build(service, @provider_id, exclude_appointment_id: exclude)
    end
    @fully_booked = fully_booked?(first_kind)
  end

  # The Fully Booked Notice: once the first choice is made and nothing in the
  # window can be booked for it, and on the time step when the window is empty.
  def fully_booked?(first_kind)
    case @step
    when "second"
      if first_kind == "service"
        BookingWindow.fully_booked?(service: Service.find(@service_id))
      else
        @provider_id != BookingPayloads::ANY_PROVIDER && BookingWindow.fully_booked?(provider: User.providers.find(@provider_id))
      end
    when "time"
      @window.empty?
    else
      false
    end
  end

  # The appointment and provider rows of a reschedule. Private or hidden-category
  # records are absent from the public payloads, so they are added for the wizard.
  def manage_payloads(record, available_services, available_providers)
    provider = record.provider
    unless available_services.any? { |row| row["id"] == record.id_services }
      available_services << BookingPayloads.service_payload(BookingPayloads.service_row(record.id_services))
                                           .merge("booking_slug" => nil)
    end
    unless available_providers.any? { |row| row["id"] == provider.id }
      available_providers << BookingPayloads.provider_payload(provider).merge("booking_slug" => nil)
    end
    provider_payload = { "id" => provider.id, "name" => provider.name,
                         "services" => provider.services.map(&:id), "timezone" => provider.effective_timezone }
    [ appointment_payload(record), provider_payload ]
  end

  # confirm/register re-render: rebuild the page vars the steps need.
  def index_vars_for_confirm
    available_services = BookingPayloads.available_services
    available_providers = BookingPayloads.available_providers
    additions = BookingPayloads.slug_additions(
      params[:service], params[:provider],
      known_service_ids: available_services.map { |row| row["id"] },
      known_provider_ids: available_providers.map { |row| row["id"] }
    )
    available_services += additions[:services]
    available_providers += additions[:providers]
    manage_mode = ActiveModel::Type::Boolean.new.cast(params[:manage_mode]) || false
    appointment = provider_payload = nil
    if manage_mode
      record = Appointment.find_by!(booking_hash: params[:appointment_hash].to_s)
      appointment, provider_payload = manage_payloads(record, available_services, available_providers)
    end
    base_index_vars(available_services, available_providers, manage_mode,
                    appointment: appointment, provider_payload: provider_payload)
    resolve_wizard_state(available_services, available_providers, manage_mode)
  end

  # [message, alert class] for a signup; an email waits once per service.
  def waitlist_signup(signup)
    return [ helpers.lang("fields_are_required"), "danger" ] if signup["name"].blank? || signup["email"].blank?
    return [ helpers.lang("invalid_email"), "danger" ] unless signup["email"].match?(URI::MailTo::EMAIL_REGEXP)
    return [ helpers.lang("waitlist_already_joined"), "warning" ] if WaitlistEntry.live.exists?(email: signup["email"], service_id: @service_id)

    provider_id = @provider_id == BookingPayloads::ANY_PROVIDER ? nil : @provider_id
    WaitlistEntry.create!(signup.merge(service_id: @service_id, provider_id: provider_id))
    [ helpers.lang("waitlist_joined"), "success" ]
  end

  def customer_form_params
    params.fetch(:customer, {}).permit(*(ALLOWED_CUSTOMER_FIELDS - %w[id]).map(&:to_sym), :notes).to_h
  end

  # The id alone is guessable: a reschedule must carry the appointment's hash too.
  def reschedule_original(appointment_id, appointment_hash)
    original = appointment_hash.present? && Appointment.find_by(id: appointment_id, booking_hash: appointment_hash.to_s)
    if !original || original.frees_slot? || BookingWindows.past?(original)
      raise ArgumentError, helpers.lang("appointment_does_not_exist_in_db")
    end
    raise ArgumentError, helpers.lang("appointment_locked") if BookingWindows.late?(original)
    original
  end

  # [message, the fields at fault], or nil when the details pass.
  def customer_error(customer)
    required = { "email" => "require_email", "phone_number" => "require_phone_number", "address" => "require_address",
                 "city" => "require_city", "zip_code" => "require_zip_code", "notes" => "require_notes" }
    missing = required.select { |_field, setting_name| Setting.get(setting_name).to_s == "1" }.keys.unshift("name")
                      .select { |field| customer[field].blank? }
    return [ helpers.lang("fields_are_required"), missing ] if missing.any?
    if Setting.get("require_phone_or_email", "1") == "1" && customer["email"].blank? && customer["phone_number"].blank?
      return [ helpers.lang("phone_or_email_required"), %w[email phone_number] ]
    end
    if customer["email"].present? && !customer["email"].match?(URI::MailTo::EMAIL_REGEXP)
      return [ helpers.lang("invalid_email"), [ "email" ] ]
    end
    nil
  end

  def register_failed(message)
    if message == helpers.lang("requested_hour_is_unavailable")
      # The slot went while the window sat on the client: back to the times with
      # a fresh window, keeping the link parameters and the reschedule route.
      manage_mode = ActiveModel::Type::Boolean.new.cast(params[:manage_mode]) || false
      route = manage_mode ? { action: :reschedule, appointment_hash: params[:appointment_hash] } : { action: :index }
      state = params.permit(:first, :service, :provider, :theme, :date, :timezone).to_h.compact_blank
      redirect_to url_for(route.merge(state).merge(step: "time",
                                                   service_id: params.dig(:appointment, :id_services),
                                                   provider_id: params.dig(:appointment, :id_users_provider))),
                  alert: message
    else
      index_vars_for_confirm
      @customer = customer_form_params
      @error = message
      @step = @reachable.include?("info") ? "final" : @reachable.last
      render :index
    end
  end

  def render_booking_message(title, text, raw_text: false, icon: "error.png")
    html_vars(
      show_message: true,
      page_title: "#{helpers.lang('page_title')} #{Setting.get('company_name')}",
      message_title: title,
      message_text: text,
      message_icon: helpers.image_path(icon),
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

  # Inside the late cancellation window: no reschedule, only a late cancel.
  def render_late_cancel(record)
    html_vars(
      page_title: helpers.lang("late_cancel_title"),
      company_color: Setting.get("company_color"),
      appointment_hash: record.booking_hash,
      notice: BookingWindows.late_notice(helpers),
      google_analytics_code: Setting.get("google_analytics_code"),
      matomo_analytics_url: Setting.get("matomo_analytics_url"),
      matomo_analytics_site_id: Setting.get("matomo_analytics_site_id")
    )
    render "booking/late_cancel", layout: "message"
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
      name: customer_params["name"] || "-",
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

  # EA row shape for the appointment_data page var (naive Y-m-d H:i:s strings).
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
    ALLOWED_CUSTOMER_FIELDS.index_with { |field| customer.public_send(field) }
  end

  # The single name field is always shown and required; only these are optional.
  # When phone-or-email mode is on, the OR rule replaces the two individual
  # require flags (the fields stay displayed, neither is required on its own).
  def field_display_vars
    fields = %w[email phone_number address city zip_code notes]
    vars = fields.flat_map { |field|
      [ [ "display_#{field}".to_sym, Setting.get("display_#{field}") ],
       [ "require_#{field}".to_sym, Setting.get("require_#{field}") ] ]
    }.to_h
    vars[:require_phone_or_email] = Setting.get("require_phone_or_email", "1")
    if vars[:require_phone_or_email] == "1"
      vars[:require_email] = "0"
      vars[:require_phone_number] = "0"
    end
    vars
  end
end
