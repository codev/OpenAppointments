# GDPR data-retention cleanup (EA Cleanup::cleanup_customer_data). Deletes customers
# created before the retention cutoff who have no appointment ending on or after it.
# Disabled when data_retention_days <= 0. Deleting a customer cascades their appointments.
module Cleanup
  module_function

  def run
    days = Setting.get("data_retention_days").to_i
    return { enabled: false, deleted: 0 } if days <= 0

    cutoff = Time.now - days.days
    customers = stale_customers(cutoff)
    customers.each(&:destroy!)
    { enabled: true, deleted: customers.size }
  end

  def stale_customers(cutoff)
    active_customer_ids = Appointment.where("end_datetime >= ?", cutoff).distinct.pluck(:id_users_customer).compact
    scope = User.customers.where(created_at: ...cutoff)
    scope = scope.where.not(id: active_customer_ids) if active_customer_ids.any?
    scope.to_a
  end
end
