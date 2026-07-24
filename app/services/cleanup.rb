# GDPR data-retention cleanup (EA Cleanup::cleanup_customer_data). Deletes customers
# created before the retention cutoff who have no appointment ending on or after it.
# Disabled when data_retention_days <= 0. Deleting a customer cascades their appointments.
module Cleanup
  module_function

  def run
    result = purge_messages
    days = Setting.get("data_retention_days").to_i
    return result.merge(enabled: false, deleted: 0) if days <= 0

    cutoff = Time.now - days.days
    customers = stale_customers(cutoff)
    customers.each(&:destroy!)
    result.merge(enabled: true, deleted: customers.size)
  end

  # Messages > Settings retention: delete messages older than N days (0 keeps all).
  def purge_messages
    days = Setting.get("messages_retention_days").to_i
    return { messages_deleted: 0 } if days <= 0

    cutoff = Time.now - days.days
    NotificationDispatch.where(created_at: ...cutoff).delete_all
    { messages_deleted: Message.where(created_at: ...cutoff).delete_all }
  end

  def stale_customers(cutoff)
    active_customer_ids = Appointment.where("end_datetime >= ?", cutoff).distinct.pluck(:id_users_customer).compact
    scope = User.customers.where(created_at: ...cutoff)
    scope = scope.where.not(id: active_customer_ids) if active_customer_ids.any?
    scope.to_a
  end
end
