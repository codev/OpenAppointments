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
      services: services_rows,
      staff: staff_rows,
      customers: customers_rows,
      appointments: appointments_rows
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

  def services_rows
    rows("Services").map do |row|
      { name: row["name"], duration: row["duration"].to_i.nonzero? || 30,
        category: row["category"].presence, price: row["price"].presence&.to_f,
        currency: row["currency"].presence, description: row["description"].presence,
        color: row["color"].presence, attendants_number: row["attendants_number"].to_i.nonzero?,
        is_private: row["is_private"] == "1" }
    end
  end

  def staff_rows
    rows("Providers").map do |row|
      plan = JSON.parse(row["working_plan"].presence || "{}") rescue {}
      { name: row["name"], email: row["email"], phone: row["phone_number"],
        services: row["services"].to_s.split("|"), working_plan: plan,
        username: row["username"].presence }
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
