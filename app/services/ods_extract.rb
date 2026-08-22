# Parses an OpenAppointments ODS backup (see DataExport) into the same data
# shape TenToEight::Extract produces, so TenToEight::Load handles both formats.
class OdsExtract
  DATETIME = "%Y-%m-%d %H:%M:%S".freeze

  def initialize(path, today: Date.current, days_back: 21, days_forward: 21)
    @path = path
    @today = today
    @days_back = days_back.to_i
    @days_forward = days_forward.to_i
  end

  def call
    @sheets = Ods.parse(@path)
    {
      categories: categories_rows,
      services: services_rows,
      staff: staff_rows,
      customers: customers_rows,
      appointments: appointments_rows,
      assistants: assistants_rows,
      admins: admins_rows,
      working_plan_exceptions: working_plan_exceptions_rows,
      notifications: notifications_rows,
      webhooks: webhooks_rows,
      consents: consents_rows,
      settings: settings_rows
    }
  end

  private

  def rows(sheet_name)
    rows = @sheets[sheet_name]
    return [] if rows.blank? || rows.length < 2

    header = rows.first.map { |cell| cell.to_s.strip }
    rows.drop(1).filter_map do |row|
      next if row.all? { |cell| cell.to_s.strip.empty? }

      header.each_with_index.to_h { |name, index| [ name, row[index].to_s ] }
    end
  end

  def settings_rows
    rows("Settings").map { |row| { name: row["name"], value: row["value"] } }
  end

  def categories_rows
    rows("Service Categories").map do |row|
      { name: row["name"], description: row["description"].presence,
        picture: row["picture"].presence, is_hidden: row["is_hidden"] == "1",
        sort_order: row["sort_order"].presence&.to_i }
    end
  end

  def services_rows
    rows("Services").map do |row|
      { name: row["name"], duration: row["duration"].to_i.nonzero? || 30,
        category: row["category"].presence, price: row["price"].presence&.to_f,
        currency: row["currency"].presence, description: row["description"].presence,
        color: row["color"].presence, attendants_number: row["attendants_number"].to_i.nonzero?,
        is_private: row["is_private"] == "1", picture: row["picture"].presence,
        sort_order: row["sort_order"].presence&.to_i }
    end
  end

  def staff_rows
    rows("Providers").map do |row|
      plan = JSON.parse(row["working_plan"].presence || "{}") rescue {}
      { name: row["name"], email: row["email"], phone: row["phone_number"],
        services: row["services"].to_s.split("|"), working_plan: plan,
        username: row["username"].presence, about: row["about"].presence,
        services_description: row["services_description"].presence,
        picture: row["picture"].presence, password_hash: row["password_hash"].presence,
        sort_order: row["sort_order"].presence&.to_i,
        is_private: row["is_private"].nil? ? nil : row["is_private"] == "1",
        sync: sync_settings(row) }
    end
  end

  # Per-user settings columns present in the sheet (older exports have none).
  def sync_settings(row)
    DataExport::SYNC_COLUMNS.filter_map do |column|
      next unless row.key?(column)

      value = row[column]
      value = (value == "1") if %w[notifications google_sync caldav_sync].include?(column)
      value = value.presence&.to_i if %w[sync_past_days sync_future_days].include?(column)
      [ column.to_sym, value.is_a?(String) ? value.presence : value ]
    end.to_h
  end

  def working_plan_exceptions_rows
    rows("Working Plan Exceptions").map do |row|
      { provider: row["provider"], start_date: row["start_date"], end_date: row["end_date"],
        start_time: row["start_time"].presence, end_time: row["end_time"].presence,
        breaks: row["breaks"].presence }
    end
  end

  def notifications_rows
    rows("Notifications").map do |row|
      { title: row["title"], event: row["event"], description: row["description"].presence,
        audiences: JSON.parse(row["audiences"].presence || "[]"),
        channels: JSON.parse(row["channels"].presence || "[]"),
        lead_days: row["lead_days"].to_i, lead_hours: row["lead_hours"].to_i,
        lead_mode: row["lead_mode"].presence || "before", send_time: row["send_time"].presence || "08:00",
        short_text: row["short_text"], long_text: row["long_text"] }
    end
  end

  def webhooks_rows
    rows("Webhooks").map do |row|
      { name: row["name"], url: row["url"], actions: row["actions"], secret_header: row["secret_header"].presence,
        secret_token: row["secret_token"].presence, is_ssl_verified: row["is_ssl_verified"] != "0",
        notes: row["notes"].presence }
    end
  end

  def consents_rows
    rows("Consents").map do |row|
      { created_at: parse_time(row["created_at"]), type: row["type"], name: row["name"].presence,
        email: row["email"].presence, ip: row["ip"].presence }
    end
  end

  def assistants_rows
    rows("Assistants").map do |row|
      { name: row["name"], email: row["email"], phone: row["phone_number"],
        timezone: row["timezone"].presence, providers: row["providers"].to_s.split("|"),
        username: row["username"].presence, password_hash: row["password_hash"].presence,
        sync: sync_settings(row) }
    end
  end

  def admins_rows
    rows("Admins").map do |row|
      { name: row["name"], email: row["email"], phone: row["phone_number"],
        timezone: row["timezone"].presence, username: row["username"].presence,
        password_hash: row["password_hash"].presence, sync: sync_settings(row) }
    end
  end

  def customers_rows
    rows("Customers").map do |row|
      notes = row["notes"].to_s
      do_not_contact = notes.start_with?(TenToEight::Load::DO_NOT_CONTACT_PREFIX)
      notes = notes.delete_prefix(TenToEight::Load::DO_NOT_CONTACT_PREFIX).strip if do_not_contact
      { ext_id: row["id"], name: row["name"], email: row["email"], phone: row["phone_number"],
        address: row["address"], city: row["city"].presence, zip: row["zip_code"].presence,
        notes: notes, do_not_contact: do_not_contact,
        pronoun: row["custom_field_1"], access: row["custom_field_2"],
        custom_field_3: row["custom_field_3"].presence, custom_field_4: row["custom_field_4"].presence,
        custom_field_5: row["custom_field_5"].presence,
        language: row["language"].presence, timezone: row["timezone"].presence }
    end
  end

  def appointments_rows
    lo = @today - @days_back
    hi = @today + @days_forward
    rows("Appointments").filter_map do |row|
      next if row["is_unavailability"] == "1"

      start_at = parse_time(row["start_datetime"])
      next unless start_at && start_at.to_date.between?(lo, hi)

      { staff: row["provider"], service: row["service"], customer_ext_id: row["customer_id"],
        start: start_at, end: parse_time(row["end_datetime"]) || start_at + 30 * 60,
        note: row["notes"], status: row["status"] }
    end
  end

  def parse_time(value)
    return nil if value.to_s.strip.empty?

    Time.strptime(value.strip, DATETIME)
  rescue ArgumentError
    nil
  end
end
