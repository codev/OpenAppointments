# Customers report: one ODS sheet of every customer with their details and,
# over the year up to now, the appointments kept, the providers and services
# booked, and the cancelled, late cancelled and rescheduled counts.
module CustomerReport
  module_function

  DETAIL_COLUMNS = %w[name email phone_number address city zip_code].freeze
  COUNT_KINDS = %w[cancelled late_cancel rescheduled].freeze

  # labels: key -> header text. now: the end of the one-year window.
  def generate(labels: ->(key) { key }, now: Time.current)
    custom_fields = CustomerColumns.custom_fields(labels)
    header = DETAIL_COLUMNS.map { |key| labels.call(key) } + custom_fields.map(&:last) +
             %w[notes appointments_in_last_year providers services].map { |key| labels.call(key) } +
             COUNT_KINDS.map { |kind| status_name(kind) }
    Ods.generate("Customers" => [ header ] + rows(custom_fields.map(&:first), now))
  end

  def status_name(kind)
    AppointmentStatus.of(kind)&.name || AppointmentStatus::DEFAULT_NAMES.fetch(kind)
  end

  def rows(custom_fields, now)
    customers = User.customers.order(:name, :email)
    appointments = Appointment.appointments
                              .where(id_users_customer: customers.select(:id), start_datetime: (now - 1.year)..now)
                              .includes(:provider, :service, :appointment_status)
                              .group_by(&:id_users_customer)
    customers.map do |customer|
      year = appointments.fetch(customer.id, [])
      kept = year.reject { |appointment| AppointmentStatus::FREE_SLOT_KINDS.include?(appointment.appointment_status&.kind) }
      DETAIL_COLUMNS.map { |attribute| customer.public_send(attribute) } +
        custom_fields.map { |attribute| customer.public_send(attribute) } +
        [ customer.notes, kept.size,
          tally(kept.map { |appointment| appointment.provider&.name }),
          tally(kept.map { |appointment| appointment.service&.name }) ] +
        COUNT_KINDS.map { |kind| year.count { |appointment| appointment.appointment_status&.kind == kind } }
    end
  end

  # "Zane (2), Kai (1)" by count then name; a lone entry is its name alone.
  def tally(names)
    counts = names.compact.tally.sort_by { |name, count| [ -count, name ] }
    return counts.first.first if counts.size == 1

    counts.map { |name, count| "#{name} (#{count})" }.join(", ")
  end
end
