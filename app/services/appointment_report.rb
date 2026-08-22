# Appointments report: one ODS sheet of the appointments in an inclusive date
# range with the chosen statuses, for the manage-data page.
module AppointmentReport
  module_function

  COLUMNS = %w[date start end duration customer email phone_number provider service status
               location notes repeats booked_on].freeze

  # labels: key -> header text. status_ids: nil for every status.
  def generate(from:, to:, status_ids: nil, labels: ->(key) { key })
    Ods.generate("Appointments" => [ COLUMNS.map { |key| labels.call(key) } ] + rows(from, to, status_ids))
  end

  def rows(from, to, status_ids)
    scope = Appointment.appointments
                       .where(start_datetime: from.beginning_of_day..to.end_of_day)
                       .includes(:customer, :provider, :service, :appointment_status, :series)
                       .order(:start_datetime)
    scope = scope.where(status_id: status_ids) if status_ids
    scope.map do |appointment|
      [ appointment.start_datetime.strftime("%Y-%m-%d"), appointment.start_datetime.strftime("%H:%M"),
        appointment.end_datetime.strftime("%H:%M"), appointment.duration_minutes,
        appointment.customer&.name, appointment.customer&.email, appointment.customer&.phone_number,
        appointment.provider&.name, appointment.service&.name, appointment.status,
        appointment.location, appointment.notes, appointment.series&.description,
        appointment.book_datetime&.strftime("%Y-%m-%d %H:%M") ]
    end
  end
end
