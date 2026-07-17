# Webhook fan-out (EA Webhooks_client). Body shape {action:, payload:} is the contract.
# Seam only until P6 adds WebhookDeliveryJob.
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

  def trigger(action, payload)
    # P6: enqueue WebhookDeliveryJob for each webhook whose actions include this action.
  end
end
