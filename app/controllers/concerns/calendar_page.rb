# Data shared by the calendar page (FullCalendar week/day/month) and the
# appointments page (per-provider day columns). Both render the same modals and
# need the same provider, service and customer rows.
module CalendarPage
  extend ActiveSupport::Concern

  private

  def render_calendar_page(page_title:, active_menu:)
    return unless require_backend_page!(:appointments)

    edit_appointment = nil
    if params[:appointment_hash].present?
      record = Appointment.find_by(booking_hash: params[:appointment_hash].to_s)
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
      EaRows.service_row(service).merge(
        "service_category_id" => service.id_service_categories,
        "service_category_name" => category_names[service.id_service_categories]
      )
    end

    customers = User.customers.order(updated_at: :desc).limit(50).to_a
    if Setting.get("limit_customer_access") == "1" && session[:role_slug] == Role::PROVIDER
      customers = customers.select { |customer| customer_access?(customer.id) }
    end
    customers = customers.map { |customer| EaRows.customer_row(customer) }

    backend_page_vars(page_title: helpers.lang(page_title), active_menu: active_menu)

    script_vars(
      first_weekday: Setting.get("first_weekday"),
      company_working_plan: Setting.get("company_working_plan"),
      privileges: session_role.permissions,
      available_providers: available_providers,
      available_services: available_services,
      assistant_providers: assistant_provider_ids,
      edit_appointment: edit_appointment,
      google_sync_feature: Setting.get("google_sync_feature") == "1",
      customers: customers,
      timezones: helpers.timezones,
      **(1..5).to_h { |i| [ :"label_custom_field_#{i}", Setting.get("label_custom_field_#{i}") ] }
    )

    html_vars(
      available_languages: Localization.available_languages,
      available_providers: available_providers,
      available_services: available_services,
      assistant_providers: assistant_provider_ids,
      appointment_status_options: JSON.parse(Setting.get("appointment_status_options", "[]")),
      **field_display_flags
    )

    render :index
  end

  def visible_providers
    providers = User.providers.joins(:provider_service_links).distinct
                    .order(:name, :email).includes(:services, :settings)
    case session[:role_slug]
    when Role::PROVIDER
      providers.where(id: session[:user_id])
    when Role::ASSISTANT
      providers.where(id: assistant_provider_ids)
    else
      providers
    end
  end
end
