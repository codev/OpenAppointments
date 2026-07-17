# External calendar sync dispatcher (EA Synchronization library).
# Seam only until P8 wires Google/CalDAV jobs.
module Synchronization
  module_function

  def appointment_saved(appointment, service, provider, customer, settings)
    # P8: enqueue Google/CalDAV sync jobs per provider settings.
  end

  def appointment_deleted(appointment, provider)
    # P8
  end
end
