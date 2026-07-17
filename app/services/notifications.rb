# Email notification orchestrator (EA Notifications library).
# Seam only until P6 wires the mailers.
module Notifications
  module_function

  def appointment_saved(appointment, service, provider, customer, settings, manage_mode: false)
    # P6: email customer, provider, admins and secretaries per notification flags.
  end

  def appointment_deleted(appointment, service, provider, customer, settings, reason: nil)
    # P6
  end
end
