# What follows a booking that is final: the notifications, the webhook and the
# waiting list entry it satisfies. A checkout booking is announced once paid.
module Bookings
  module_function

  def announce(appointment, manage_mode: false)
    service = appointment.service
    customer = appointment.customer
    Notifications.appointment_saved(appointment, service, appointment.provider, customer, manage_mode: manage_mode)
    Webhooks.trigger(Webhooks::APPOINTMENT_SAVE, appointment)
    WaitlistEntry.where(email: customer.email, service_id: service.id).delete_all if customer.email.present?
  end
end
