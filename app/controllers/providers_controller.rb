# Providers admin CRUD, port of EA's Providers controller.
class ProvidersController < ApplicationController
  include BackendPage
  include UserCrud

  layout "backend"

  # EA allowed_provider_fields (mobile_number is not allowed, matching EA).
  ALLOWED_FIELDS = %w[id name email alt_number phone_number address city state
                      zip_code notes timezone language is_private ldap_dn id_roles settings
                      services].freeze
  ALLOWED_SETTING_FIELDS = %w[username password working_plan working_plan_exceptions
                              notifications calendar_view].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:users)

    services = Service.order(:name).map { |service| { "id" => service.id, "name" => service.name } }

    backend_page_vars(page_title: helpers.lang("providers"), active_menu: "users")
    script_vars(
      company_working_plan: Setting.get("company_working_plan"),
      first_weekday: Setting.get("first_weekday"),
      min_password_length: Passwords::MIN_LENGTH,
      timezones: helpers.timezones,
      services: services
    )
    html_vars(
      available_languages: Localization.available_languages,
      services: Service.order(:name).map { |service| EaRows.service_row(service) }
    )
    render :index
  end

  # POST /providers/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :users)

    providers = search_users(User.providers.includes(:services, :settings), params[:keyword].to_s,
                             params.fetch(:limit, 1000).to_i, params.fetch(:offset, 0).to_i)

    render json: providers.map { |provider| EaRows.provider_row(provider) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /providers/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :users)

    save_provider(User.new(role: Role.find_by!(slug: Role::PROVIDER)))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # GET/POST /providers/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :users)

    provider_id = positive_id!(params.require(:provider_id), "provider")
    render json: EaRows.provider_row(User.providers.find(provider_id))
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /providers/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :users)

    save_provider(User.providers.find(permitted_provider.fetch("id")))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /providers/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :users)

    provider_id = positive_id!(params.require(:provider_id), "provider")
    provider = User.providers.find(provider_id)
    row = EaRows.provider_row(provider)
    provider.destroy!
    Webhooks.trigger(Webhooks::PROVIDER_DELETE, row)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def permitted_provider
    value = params.require(:provider)
    if value.is_a?(ActionController::Parameters)
      value = value.permit(*(ALLOWED_FIELDS - %w[settings services]).map(&:to_sym),
                           services: [], settings: ALLOWED_SETTING_FIELDS.map(&:to_sym)).to_h
    end
    value
  end

  def save_provider(provider)
    provider_params = permitted_provider
    settings = (provider_params["settings"] || {}).slice(*ALLOWED_SETTING_FIELDS)
    service_ids = provider_params["services"] || []

    validate_user_payload!(provider_params, settings, "provider")
    validate_unique_role_email!(User.providers, provider_params)

    # EA optional fields: working_plan defaults to the company plan, exceptions to none.
    settings["working_plan"] = Setting.get("company_working_plan") unless settings.key?("working_plan")
    settings["working_plan_exceptions"] = "{}" unless settings.key?("working_plan_exceptions")

    provider.assign_attributes(
      provider_params.except("id", "settings", "services", "alt_number", "id_roles")
    )
    provider.save!
    apply_user_settings!(provider, settings)
    set_service_ids(provider, service_ids)

    Webhooks.trigger(Webhooks::PROVIDER_SAVE, EaRows.provider_row(provider))
    render json: { success: true, id: provider.id }
  end

  # EA Providers_model::set_service_ids: re-insert the join rows.
  def set_service_ids(provider, service_ids)
    provider.provider_service_links.delete_all
    Array(service_ids).each do |service_id|
      ServiceProviderLink.create!(id_users: provider.id, id_services: service_id)
    end
  end
end
