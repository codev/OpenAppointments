# Webhook fan-out (EA Webhooks_client). Body shape {action:, payload:} is the contract.
# Seam only until P6 adds WebhookDeliveryJob.
module Webhooks
  APPOINTMENT_SAVE = "appointment_save".freeze
  APPOINTMENT_DELETE = "appointment_delete".freeze

  module_function

  def trigger(action, payload)
    # P6: enqueue WebhookDeliveryJob for each webhook whose actions include this action.
  end
end
