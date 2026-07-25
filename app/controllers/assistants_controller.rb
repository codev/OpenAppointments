# Assistants admin CRUD, port of EA's Assistants controller.
class AssistantsController < ApplicationController
  include BackendPage
  include PictureUpload
  include UserCrud

  layout "backend"

  # EA allowed_assistant_fields (mobile_number is not allowed, matching EA).
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

    backend_page_vars(page_title: helpers.lang("assistants"), active_menu: "users")
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

  # POST /assistants/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :users)

    assistants = search_users(User.assistants.includes(:providers, :settings), params[:keyword].to_s,
                               params.fetch(:limit, 1000).to_i, params.fetch(:offset, 0).to_i)

    render json: assistants.map { |assistant| EaRows.assistant_row(assistant) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /assistants/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :users)

    save_assistant(User.new(role: Role.find_by!(slug: Role::ASSISTANT)))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # GET/POST /assistants/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :users)

    assistant_id = positive_id!(params.require(:assistant_id), "assistant")
    render json: EaRows.assistant_row(User.assistants.find(assistant_id))
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /assistants/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :users)

    save_assistant(User.assistants.find(permitted_assistant.fetch("id")))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /assistants/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :users)

    assistant_id = positive_id!(params.require(:assistant_id), "assistant")
    assistant = User.assistants.find(assistant_id)
    row = EaRows.assistant_row(assistant)
    assistant.destroy!
    Webhooks.trigger(Webhooks::ASSISTANT_DELETE, row)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def permitted_assistant
    value = params.require(:assistant)
    if value.is_a?(ActionController::Parameters)
      value = value.permit(*(ALLOWED_FIELDS - %w[settings providers]).map(&:to_sym),
                           providers: [], settings: ALLOWED_SETTING_FIELDS.map(&:to_sym)).to_h
    end
    value
  end

  def save_assistant(assistant)
    assistant_params = permitted_assistant
    settings = (assistant_params["settings"] || {}).slice(*ALLOWED_SETTING_FIELDS)
    provider_ids = assistant_params["providers"] || []

    validate_user_payload!(assistant_params, settings, "assistant")
    validate_unique_role_email!(User.assistants, assistant_params)

    assistant.assign_attributes(
      assistant_params.except("id", "settings", "providers", "alt_number", "id_roles")
    )
    assistant.save!
    apply_user_settings!(assistant, settings)
    set_provider_ids(assistant, provider_ids)

    Webhooks.trigger(Webhooks::ASSISTANT_SAVE, EaRows.assistant_row(assistant))
    render json: { success: true, id: assistant.id }
  end

  # EA Assistants_model::save_provider_ids: re-insert the join rows.
  def set_provider_ids(assistant, provider_ids)
    assistant.assistant_provider_links.delete_all
    Array(provider_ids).each do |provider_id|
      AssistantProviderLink.create!(id_users_assistant: assistant.id, id_users_provider: provider_id)
    end
  end

  def picture_record = User.assistants.find(params[:id])

  def picture_permission_resource = :users
end
