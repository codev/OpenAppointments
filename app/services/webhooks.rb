# Webhook fan-out (EA Webhooks_client::trigger). Body shape {action:, payload:} is the
# contract. Delivery happens on Solid Queue via WebhookDeliveryJob.
module Webhooks
  APPOINTMENT_SAVE = "appointment_save".freeze
  APPOINTMENT_DELETE = "appointment_delete".freeze
  UNAVAILABILITY_SAVE = "unavailability_save".freeze
  UNAVAILABILITY_DELETE = "unavailability_delete".freeze
  CUSTOMER_SAVE = "customer_save".freeze
  CUSTOMER_DELETE = "customer_delete".freeze
  SERVICE_SAVE = "service_save".freeze
  SERVICE_DELETE = "service_delete".freeze
  SERVICE_CATEGORY_SAVE = "service_category_save".freeze
  SERVICE_CATEGORY_DELETE = "service_category_delete".freeze
  PROVIDER_SAVE = "provider_save".freeze
  PROVIDER_DELETE = "provider_delete".freeze
  SECRETARY_SAVE = "secretary_save".freeze
  SECRETARY_DELETE = "secretary_delete".freeze
  ADMIN_SAVE = "admin_save".freeze
  ADMIN_DELETE = "admin_delete".freeze
  BLOCKED_PERIOD_SAVE = "blocked_period_save".freeze
  BLOCKED_PERIOD_DELETE = "blocked_period_delete".freeze

  module_function

  # payload: an EaRows hash or an AR record (serialized to its EA row).
  def trigger(action, payload)
    payload = to_row(payload)

    Webhook.find_each do |webhook|
      WebhookDeliveryJob.perform_later(webhook.id, action, payload) if webhook.handles?(action)
    end
  end

  def to_row(payload)
    case payload
    when Appointment then EaRows.appointment_row(payload)
    when Service then EaRows.service_row(payload)
    when ServiceCategory then EaRows.service_category_row(payload)
    when BlockedPeriod then EaRows.blocked_period_row(payload)
    when Webhook then EaRows.webhook_row(payload)
    when User then EaRows.user_row(payload)
    else payload
    end
  end
end
