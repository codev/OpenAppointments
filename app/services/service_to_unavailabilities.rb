# Turns the appointments of a service into busy time of one type: for salons
# that booked meetings, leave or admin as a hidden service on a house customer.
# Rows sharing a start, end and notes become one group. Reminder records go
# with them; the service itself is left empty for the admin to delete.
module ServiceToUnavailabilities
  module_function

  # Returns { type:, converted:, groups:, dispatches: }; dry_run counts only.
  def run(service, type_name, dry_run: false)
    rows = Appointment.appointments.where(id_services: service.id).order(:start_datetime, :id).to_a
    slots = rows.group_by { |row| [ row.start_datetime, row.end_datetime, row.notes.to_s.strip ] }
    dispatches = NotificationDispatch.where(appointment_id: rows.map(&:id))
    result = { type: type_name.to_s.strip, converted: rows.size, groups: slots.size, dispatches: dispatches.count }
    return result if dry_run

    Activity.silenced do
      Appointment.transaction do
        type = UnavailabilityType.resolve(type_name, color: service.color)
        dispatches.delete_all
        slots.each_value do |group|
          group_id = SecureRandom.uuid
          group.each do |row|
            row.update!(is_unavailability: true, unavailability_type: type, unavailability_group: group_id,
                        id_services: nil, id_users_customer: nil, status_id: nil, series_id: nil)
          end
        end
      end
    end
    result
  end
end
