# Full-data ODS export for the manage-data page. Sheet and column names match
# what OdsExtract expects, so the file doubles as a re-importable backup.
module DataExport
  DATETIME = "%Y-%m-%d %H:%M:%S".freeze

  module_function

  def generate
    Ods.generate(sheets)
  end

  def sheets
    {
      "Service Categories" => categories_sheet,
      "Services" => services_sheet,
      "Providers" => providers_sheet,
      "Assistants" => assistants_sheet,
      "Admins" => admins_sheet,
      "Customers" => customers_sheet,
      "Appointments" => appointments_sheet,
      "Blocked Periods" => blocked_periods_sheet,
      "Settings" => settings_sheet
    }
  end

  def categories_sheet
    rows = ServiceCategory.with_attached_picture.order(:name).map do |category|
      [ category.name, category.description, picture_name(category), category.is_hidden ? "1" : "0",
        category.sort_order ]
    end
    [ %w[name description picture is_hidden sort_order] ] + rows
  end

  def services_sheet
    rows = Service.includes(:category).with_attached_picture.order(:name).map do |service|
      [ service.name, service.duration, service.price, service.currency, service.category&.name,
        service.description, service.color, service.attendants_number, service.is_private ? "1" : "0",
        picture_name(service), service.sort_order ]
    end
    [ %w[name duration price currency category description color attendants_number is_private picture
         sort_order] ] + rows
  end

  def providers_sheet
    rows = User.providers.includes(:services, :settings).with_attached_picture.order(:name).map do |provider|
      [ provider.name, provider.email, provider.phone_number, provider.timezone,
        provider.services.map(&:name).join("|"), provider.settings&.working_plan,
        provider.settings&.username, provider.about, provider.services_description,
        picture_name(provider), provider.settings&.password, provider.sort_order,
        provider.is_private ? "1" : "0" ]
    end
    [ %w[name email phone_number timezone services working_plan username
         about services_description picture password_hash sort_order is_private] ] + rows
  end

  def picture_name(record)
    record.picture.attached? ? record.picture.filename.to_s : nil
  end

  def assistants_sheet
    rows = User.assistants.includes(:providers, :settings).order(:name).map do |assistant|
      [ assistant.name, assistant.email, assistant.phone_number, assistant.timezone,
        assistant.providers.map(&:name).join("|"), assistant.settings&.username,
        assistant.settings&.password ]
    end
    [ %w[name email phone_number timezone providers username password_hash] ] + rows
  end

  def admins_sheet
    rows = User.admins.includes(:settings).order(:name).map do |admin|
      [ admin.name, admin.email, admin.phone_number, admin.timezone, admin.settings&.username,
        admin.settings&.password ]
    end
    [ %w[name email phone_number timezone username password_hash] ] + rows
  end

  def customers_sheet
    rows = User.customers.order(:id).map do |customer|
      [ customer.id, customer.name, customer.email, customer.phone_number, customer.address,
        customer.city, customer.zip_code, customer.notes, customer.custom_field_1,
        customer.custom_field_2, customer.custom_field_3, customer.custom_field_4,
        customer.custom_field_5, customer.language, customer.timezone ]
    end
    [ %w[id name email phone_number address city zip_code notes custom_field_1 custom_field_2
         custom_field_3 custom_field_4 custom_field_5 language timezone] ] + rows
  end

  def appointments_sheet
    rows = Appointment.includes(:provider, :customer, :service).order(:start_datetime).map do |appointment|
      [ appointment.start_datetime&.strftime(DATETIME), appointment.end_datetime&.strftime(DATETIME),
        appointment.provider&.name, appointment.id_users_customer, appointment.service&.name,
        appointment.notes, appointment.status, appointment.is_unavailability ? "1" : "0",
        appointment.booking_hash ]
    end
    [ %w[start_datetime end_datetime provider customer_id service notes status is_unavailability
         booking_hash] ] + rows
  end

  def blocked_periods_sheet
    rows = BlockedPeriod.order(:start_datetime).map do |period|
      [ period.name, period.start_datetime&.strftime(DATETIME),
        period.end_datetime&.strftime(DATETIME), period.notes ]
    end
    [ %w[name start_datetime end_datetime notes] ] + rows
  end

  def settings_sheet
    [ %w[name value] ] + Setting.order(:name).map { |setting| [ setting.name, setting.value ] }
  end
end
