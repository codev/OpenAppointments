# Once a customer's appointment has happened, their unread messages count as
# seen: the stylist met them. Marking them read clears the unread badges and
# the unread-first ordering; the Inbox is untouched because it runs on done_at.
module MessageReads
  module_function

  # Marks read every unread incoming message that arrived before an appointment
  # of its customer ended, for appointments that ended by now. Rerunning finds
  # nothing new, so the recurring scan needs no watermark.
  def after_appointments(now = Time.current)
    earliest_unread = Message.unread.where.not(customer_id: nil).group(:customer_id).minimum(:created_at)
    earliest_unread.each do |customer_id, arrived_at|
      ended_at = latest_appointment_end(customer_id, arrived_at, now)
      next unless ended_at

      Message.unread.where(customer_id: customer_id, created_at: ..ended_at).update_all(read_at: now)
    end
  end

  # The latest end, as an absolute time, of a kept appointment that ended
  # between the two instants. Stored times are the stylist's wall clock, so the
  # query brackets by a day each side and the zone-aware check decides.
  def latest_appointment_end(customer_id, from, now)
    Appointment.appointments
               .where(id_users_customer: customer_id, end_datetime: (from - 1.day)..(now + 1.day))
               .not_kind(AppointmentStatus::FREE_SLOT_KINDS + %w[no_show])
               .includes(:provider)
               .map { |appointment| BookingWindows.ends_at(appointment) }
               .select { |ended_at| ended_at >= from && ended_at <= now }
               .max
  end
end
