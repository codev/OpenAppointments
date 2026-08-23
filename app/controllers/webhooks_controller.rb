# Webhooks admin: Rails views inside Turbo Frames. Saving/removing webhooks does
# not itself trigger webhook deliveries.
class WebhooksController < ApplicationController
  include CrudPage

  PAGE = { resource: :webhooks, menu: "system_settings", title: "webhooks",
           saved: "webhook_saved", deleted: "webhook_deleted" }.freeze

  AVAILABLE_ACTIONS = [
    Webhooks::APPOINTMENT_SAVE, Webhooks::APPOINTMENT_DELETE,
    Webhooks::UNAVAILABILITY_SAVE, Webhooks::UNAVAILABILITY_DELETE,
    Webhooks::BLOCKED_PERIOD_SAVE, Webhooks::BLOCKED_PERIOD_DELETE,
    Webhooks::CUSTOMER_SAVE, Webhooks::CUSTOMER_DELETE,
    Webhooks::SERVICE_SAVE, Webhooks::SERVICE_DELETE,
    Webhooks::SERVICE_CATEGORY_SAVE, Webhooks::SERVICE_CATEGORY_DELETE,
    Webhooks::PROVIDER_SAVE, Webhooks::PROVIDER_DELETE,
    Webhooks::ASSISTANT_SAVE, Webhooks::ASSISTANT_DELETE,
    Webhooks::ADMIN_SAVE, Webhooks::ADMIN_DELETE
  ].freeze

  private

  def record_scope = Webhook.order(updated_at: :desc)

  def filter(scope, keyword)
    return scope if keyword.blank?

    pattern = "%#{Webhook.sanitize_sql_like(keyword)}%"
    scope.where("name LIKE :pattern OR url LIKE :pattern OR actions LIKE :pattern", pattern: pattern)
  end

  # actions arrive as checkbox values and are stored comma-separated, as in EA.
  def record_params
    permitted = params.require(:webhook).permit(:name, :url, :secret_header, :secret_token, :is_ssl_verified, :notes,
                                                actions: [])
    permitted[:actions] = (Array(permitted[:actions]) & AVAILABLE_ACTIONS).join(",") if params[:webhook].key?(:actions)
    permitted
  end
end
