# Webhooks admin CRUD, port of EA's Webhooks controller. Saving/removing webhooks
# does not itself trigger webhook deliveries.
class WebhooksController < ApplicationController
  include BackendPage

  layout "backend"

  ALLOWED_FIELDS = %w[id name url actions secret_header secret_token is_ssl_verified notes].freeze

  AVAILABLE_ACTIONS = [
    Webhooks::APPOINTMENT_SAVE, Webhooks::APPOINTMENT_DELETE,
    Webhooks::UNAVAILABILITY_SAVE, Webhooks::UNAVAILABILITY_DELETE,
    Webhooks::BLOCKED_PERIOD_SAVE, Webhooks::BLOCKED_PERIOD_DELETE,
    Webhooks::CUSTOMER_SAVE, Webhooks::CUSTOMER_DELETE,
    Webhooks::SERVICE_SAVE, Webhooks::SERVICE_DELETE,
    Webhooks::SERVICE_CATEGORY_SAVE, Webhooks::SERVICE_CATEGORY_DELETE,
    Webhooks::PROVIDER_SAVE, Webhooks::PROVIDER_DELETE,
    Webhooks::SECRETARY_SAVE, Webhooks::SECRETARY_DELETE,
    Webhooks::ADMIN_SAVE, Webhooks::ADMIN_DELETE
  ].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:webhooks)

    backend_page_vars(page_title: helpers.lang("webhooks"), active_menu: "system_settings")
    html_vars(available_actions: AVAILABLE_ACTIONS)
    render :index
  end

  # POST /webhooks/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :webhooks)

    webhooks = search_webhooks(params[:keyword].to_s, params.fetch(:limit, 1000).to_i,
                               params.fetch(:offset, 0).to_i)

    render json: webhooks.map { |webhook| EaRows.webhook_row(webhook) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /webhooks/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :webhooks)

    save_webhook(Webhook.new)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /webhooks/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :webhooks)

    save_webhook(Webhook.find(permitted_webhook.fetch("id")))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /webhooks/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :webhooks)

    webhook_id = params.require(:webhook_id).to_i
    raise ArgumentError, "Invalid webhook ID provided." unless webhook_id.positive?

    Webhook.find(webhook_id).destroy!
    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # GET/POST /webhooks/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :webhooks)

    webhook_id = params.require(:webhook_id).to_i
    raise ArgumentError, "Invalid webhook ID provided." unless webhook_id.positive?

    render json: EaRows.webhook_row(Webhook.find(webhook_id))
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def permitted_webhook
    value = params.require(:webhook)
    value = value.permit(*ALLOWED_FIELDS.map(&:to_sym)).to_h if value.is_a?(ActionController::Parameters)
    value
  end

  def save_webhook(webhook)
    webhook.assign_attributes(permitted_webhook.except("id"))
    webhook.save!
    render json: { success: true, id: webhook.id }
  end

  def search_webhooks(keyword, limit, offset)
    scope = Webhook.order(updated_at: :desc).limit(limit).offset(offset)
    return scope if keyword.blank?

    pattern = "%#{Webhook.sanitize_sql_like(keyword)}%"
    scope.where("name LIKE :pattern OR url LIKE :pattern OR actions LIKE :pattern", pattern: pattern)
  end
end
