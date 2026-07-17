# Secretaries admin CRUD, port of EA's Secretaries controller.
class SecretariesController < ApplicationController
  include BackendPage
  include PictureUpload
  include UserCrud

  layout "backend"

  # EA allowed_secretary_fields (mobile_number is not allowed, matching EA).
  ALLOWED_FIELDS = %w[id name email alt_number phone_number address city state
                      zip_code notes timezone language is_private ldap_dn id_roles settings
                      providers].freeze
  ALLOWED_SETTING_FIELDS = %w[username password notifications calendar_view].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:users)

    providers = User.providers.order(:name).map do |provider|
      { "id" => provider.id, "name" => provider.name }
    end

    backend_page_vars(page_title: helpers.lang("secretaries"), active_menu: "users")
    script_vars(
      timezones: helpers.timezones,
      min_password_length: Passwords::MIN_LENGTH,
      providers: providers
    )
    html_vars(
      available_languages: Localization.available_languages,
      providers: providers
    )
    render :index
  end

  # POST /secretaries/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :users)

    secretaries = search_users(User.secretaries.includes(:providers, :settings), params[:keyword].to_s,
                               params.fetch(:limit, 1000).to_i, params.fetch(:offset, 0).to_i)

    render json: secretaries.map { |secretary| EaRows.secretary_row(secretary) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /secretaries/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :users)

    save_secretary(User.new(role: Role.find_by!(slug: Role::SECRETARY)))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # GET/POST /secretaries/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :users)

    secretary_id = positive_id!(params.require(:secretary_id), "secretary")
    render json: EaRows.secretary_row(User.secretaries.find(secretary_id))
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /secretaries/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :users)

    save_secretary(User.secretaries.find(permitted_secretary.fetch("id")))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /secretaries/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :users)

    secretary_id = positive_id!(params.require(:secretary_id), "secretary")
    secretary = User.secretaries.find(secretary_id)
    row = EaRows.secretary_row(secretary)
    secretary.destroy!
    Webhooks.trigger(Webhooks::SECRETARY_DELETE, row)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def permitted_secretary
    value = params.require(:secretary)
    if value.is_a?(ActionController::Parameters)
      value = value.permit(*(ALLOWED_FIELDS - %w[settings providers]).map(&:to_sym),
                           providers: [], settings: ALLOWED_SETTING_FIELDS.map(&:to_sym)).to_h
    end
    value
  end

  def save_secretary(secretary)
    secretary_params = permitted_secretary
    settings = (secretary_params["settings"] || {}).slice(*ALLOWED_SETTING_FIELDS)
    provider_ids = secretary_params["providers"] || []

    validate_user_payload!(secretary_params, settings, "secretary")
    validate_unique_role_email!(User.secretaries, secretary_params)

    secretary.assign_attributes(
      secretary_params.except("id", "settings", "providers", "alt_number", "id_roles")
    )
    secretary.save!
    apply_user_settings!(secretary, settings)
    set_provider_ids(secretary, provider_ids)

    Webhooks.trigger(Webhooks::SECRETARY_SAVE, EaRows.secretary_row(secretary))
    render json: { success: true, id: secretary.id }
  end

  # EA Secretaries_model::save_provider_ids: re-insert the join rows.
  def set_provider_ids(secretary, provider_ids)
    secretary.secretary_provider_links.delete_all
    Array(provider_ids).each do |provider_id|
      SecretaryProviderLink.create!(id_users_secretary: secretary.id, id_users_provider: provider_id)
    end
  end

  def picture_record = User.secretaries.find(params[:id])

  def picture_permission_resource = :users
end
