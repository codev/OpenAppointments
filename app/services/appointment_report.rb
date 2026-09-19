# Appointments report: one ODS sheet of the appointments in an inclusive date
# range with the chosen statuses, for the manage-data page.
module AppointmentReport
  module_function

  COLUMNS = %w[date start end duration customer email phone_number provider service status
               location notes repeats booked_on].freeze

  # labels: key -> header text. status_ids: nil for every status; a list that
  # covers every status also includes appointments with no status. The
  # displayed customer custom fields and the customer notes follow the columns.
  def generate(from:, to:, status_ids: nil, labels: ->(key) { key })
    custom_fields = CustomerColumns.custom_fields(labels)
    header = COLUMNS.map { |key| labels.call(key) } + custom_fields.map(&:last) + [ labels.call("customer_notes") ]
    Ods.generate("Appointments" => [ header ] + rows(from, to, status_ids, custom_fields.map(&:first)))
  end

  def rows(from, to, status_ids, custom_fields)
    scope = Appointment.appointments
                       .where(start_datetime: from.beginning_of_day..to.end_of_day)
                       .includes(:customer, :provider, :service, :appointment_status, :series)
                       .order(:start_datetime)
    if status_ids && (AppointmentStatus.pluck(:id) - status_ids).empty?
      status_ids = nil
    end
    scope = scope.where(status_id: status_ids) if status_ids
    scope.map do |appointment|
      customer = appointment.customer
      [ appointment.start_datetime.strftime("%Y-%m-%d"), appointment.start_datetime.strftime("%H:%M"),
        appointment.end_datetime.strftime("%H:%M"), appointment.duration_minutes,
        customer&.name, customer&.email, customer&.phone_number,
        appointment.provider&.name, appointment.service&.name, appointment.status,
        appointment.location, appointment.notes, appointment.series&.description,
        appointment.book_datetime&.strftime("%Y-%m-%d %H:%M") ] +
        custom_fields.map { |attribute| customer&.public_send(attribute) } + [ customer&.notes ]
    end
  end
end
