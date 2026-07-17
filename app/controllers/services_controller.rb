# Services admin CRUD, port of EA's Services controller.
class ServicesController < ApplicationController
  include BackendPage

  layout "backend"

  ALLOWED_FIELDS = %w[id name duration price currency description color location slot_interval
                      attendants_number is_private id_service_categories providers].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:services)

    providers = User.providers.order(:first_name, :last_name).includes(:services, :settings)
                    .map { |provider| EaRows.provider_row(provider) }

    backend_page_vars(page_title: helpers.lang("services"), active_menu: "services")
    script_vars(event_minimum_duration: Appointment::EVENT_MINIMUM_DURATION, providers: providers)
    html_vars(providers: providers)
    render :index
  end

  # POST /services/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :services)

    services = search_services(params[:keyword].to_s, params.fetch(:limit, 1000).to_i,
                               params.fetch(:offset, 0).to_i)

    render json: services.map { |service| service_response(service) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /services/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :services)

    save_service(Service.new)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # GET/POST /services/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :services)

    service_id = params.require(:service_id).to_i
    raise ArgumentError, "Invalid service ID provided." unless service_id.positive?

    render json: EaRows.service_row(Service.find(service_id))
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /services/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :services)

    save_service(Service.find(permitted_service.fetch("id")))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /services/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :services)

    service_id = params.require(:service_id).to_i
    raise ArgumentError, "Invalid service ID provided." unless service_id.positive?

    service = Service.find(service_id)
    row = EaRows.service_row(service)
    service.destroy!
    Webhooks.trigger(Webhooks::SERVICE_DELETE, row)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def service_response(service)
    EaRows.service_row(service).merge("providers" => service.provider_links.map(&:id_users))
  end

  def permitted_service
    value = params.require(:service)
    value = value.permit(*ALLOWED_FIELDS.map(&:to_sym), providers: []).to_h if value.is_a?(ActionController::Parameters)
    value
  end

  def save_service(service)
    service_params = permitted_service
    provider_ids = service_params["providers"]
    service.assign_attributes(service_params.except("id", "providers"))
    service.save!
    set_provider_ids(service, provider_ids) unless provider_ids.nil?
    Webhooks.trigger(Webhooks::SERVICE_SAVE, EaRows.service_row(service))
    render json: { success: true, id: service.id }
  end

  def set_provider_ids(service, provider_ids)
    service.provider_links.delete_all
    Array(provider_ids).each do |provider_id|
      ServiceProviderLink.create!(id_services: service.id, id_users: provider_id)
    end
  end

  def search_services(keyword, limit, offset)
    scope = Service.order(updated_at: :desc).limit(limit).offset(offset)
    return scope if keyword.blank?

    pattern = "%#{Service.sanitize_sql_like(keyword)}%"
    scope.where("name LIKE :pattern OR description LIKE :pattern", pattern: pattern)
  end
end
