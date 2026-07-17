# EA-shaped row hashes for backend JSON responses (mirror of CI result_array + model
# find/load output). Datetimes are naive Y-m-d H:i:s strings; hash column is exposed
# as "hash". Provider/admin settings are filtered like EA's filter_sensitive_user_data.
module EaRows
  SENSITIVE_SETTINGS = %w[password salt password_reset_token password_reset_expires
                          google_token caldav_password caldav_username].freeze

  module_function

  def dt(value)
    value&.strftime("%Y-%m-%d %H:%M:%S")
  end

  def appointment_row(appointment)
    {
      "id" => appointment.id,
      "book_datetime" => dt(appointment.book_datetime),
      "start_datetime" => dt(appointment.start_datetime),
      "end_datetime" => dt(appointment.end_datetime),
      "location" => appointment.location, "meeting_link" => appointment.meeting_link,
      "notes" => appointment.notes, "hash" => appointment.booking_hash,
      "color" => appointment.color, "status" => appointment.status,
      "is_unavailability" => appointment.is_unavailability,
      "id_users_provider" => appointment.id_users_provider,
      "id_users_customer" => appointment.id_users_customer,
      "id_services" => appointment.id_services,
      "id_google_calendar" => appointment.id_google_calendar,
      "id_caldav_calendar" => appointment.id_caldav_calendar
    }
  end

  def user_row(user)
    {
      "id" => user.id, "name" => user.name,
      "email" => user.email, "mobile_number" => user.mobile_number,
      "phone_number" => user.phone_number, "address" => user.address, "city" => user.city,
      "state" => user.state, "zip_code" => user.zip_code, "notes" => user.notes,
      "timezone" => user.timezone, "language" => user.language,
      "is_private" => user.is_private, "ldap_dn" => user.ldap_dn,
      "custom_field_1" => user.custom_field_1, "custom_field_2" => user.custom_field_2,
      "custom_field_3" => user.custom_field_3, "custom_field_4" => user.custom_field_4,
      "custom_field_5" => user.custom_field_5, "id_roles" => user.id_roles
    }
  end

  def customer_row(user)
    user_row(user)
  end

  def provider_row(provider)
    user_row(provider).merge(
      "settings" => provider_settings_row(provider),
      "services" => provider.services.map(&:id)
    )
  end

  # EA Providers_model::get_settings + filter_sensitive_user_settings.
  def provider_settings_row(provider)
    settings = provider.settings
    return {} unless settings

    row = settings.attributes.except("id_users", "created_at", "updated_at", *SENSITIVE_SETTINGS)
    row["working_plan_exceptions"] = working_plan_exceptions_api(provider.id).to_json
    row
  end

  # EA Working_plan_exceptions_model::get_all_by_provider (camelCase API shape).
  def working_plan_exceptions_api(provider_id)
    WorkingPlanException.where(id_users_provider: provider_id).order(:start_date).map do |exception|
      {
        "id" => exception.id,
        "startDate" => exception.start_date.strftime("%Y-%m-%d"),
        "endDate" => exception.end_date.strftime("%Y-%m-%d"),
        "startTime" => exception.start_time,
        "endTime" => exception.end_time,
        "breaks" => exception.break_list
      }
    end
  end

  # EA Admins/Secretaries_model::get_settings (no working_plan_exceptions key).
  def user_settings_row(user)
    settings = user.settings
    return {} unless settings

    settings.attributes.except("id_users", "created_at", "updated_at", *SENSITIVE_SETTINGS)
  end

  def secretary_row(secretary)
    user_row(secretary).merge(
      "settings" => user_settings_row(secretary),
      "providers" => secretary.providers.map(&:id)
    )
  end

  def admin_row(admin)
    user_row(admin).merge("settings" => user_settings_row(admin))
  end

  def service_row(service)
    {
      "id" => service.id, "name" => service.name, "duration" => service.duration,
      "price" => service.price&.to_f, "currency" => service.currency,
      "description" => service.description, "location" => service.location,
      "color" => service.color, "slot_interval" => service.slot_interval,
      "attendants_number" => service.attendants_number, "is_private" => service.is_private,
      "id_service_categories" => service.id_service_categories
    }
  end

  def service_category_row(category)
    { "id" => category.id, "name" => category.name, "description" => category.description }
  end

  def webhook_row(webhook)
    {
      "id" => webhook.id, "name" => webhook.name, "url" => webhook.url,
      "actions" => webhook.actions, "secret_header" => webhook.secret_header,
      "secret_token" => webhook.secret_token, "is_ssl_verified" => webhook.is_ssl_verified,
      "notes" => webhook.notes
    }
  end

  def blocked_period_row(period)
    {
      "id" => period.id, "name" => period.name,
      "start_datetime" => dt(period.start_datetime), "end_datetime" => dt(period.end_datetime),
      "notes" => period.notes
    }
  end
end
