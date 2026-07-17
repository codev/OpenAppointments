# Admins admin CRUD, port of EA's Admins controller.
class AdminsController < ApplicationController
  include BackendPage
  include PictureUpload
  include UserCrud

  layout "backend"

  ALLOWED_FIELDS = %w[id name email mobile_number phone_number address city state
                      zip_code notes timezone language ldap_dn settings].freeze
  ALLOWED_SETTING_FIELDS = %w[username password notifications calendar_view].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:users)

    backend_page_vars(page_title: helpers.lang("admins"), active_menu: "users")
    script_vars(
      timezones: helpers.timezones,
      min_password_length: Passwords::MIN_LENGTH
    )
    html_vars(available_languages: Localization.available_languages)
    render :index
  end

  # POST /admins/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :users)

    admins = search_users(User.admins.includes(:settings), params[:keyword].to_s,
                          params.fetch(:limit, 1000).to_i, params.fetch(:offset, 0).to_i)

    render json: admins.map { |admin| EaRows.admin_row(admin) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /admins/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :users)

    save_admin(User.new(role: Role.find_by!(slug: Role::ADMIN)))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # GET/POST /admins/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :users)

    admin_id = positive_id!(params.require(:admin_id), "admin")
    render json: EaRows.admin_row(User.admins.find(admin_id))
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /admins/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :users)

    save_admin(User.admins.find(permitted_admin.fetch("id")))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /admins/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :users)

    admin_id = positive_id!(params.require(:admin_id), "admin")

    # EA prevents self-deletion.
    raise ArgumentError, "You cannot delete your own account." if admin_id == session[:user_id].to_i

    admin = User.admins.find(admin_id)
    row = EaRows.admin_row(admin)
    admin.destroy!
    Webhooks.trigger(Webhooks::ADMIN_DELETE, row)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def permitted_admin
    value = params.require(:admin)
    if value.is_a?(ActionController::Parameters)
      value = value.permit(*(ALLOWED_FIELDS - %w[settings]).map(&:to_sym),
                           settings: ALLOWED_SETTING_FIELDS.map(&:to_sym)).to_h
    end
    value
  end

  def save_admin(admin)
    admin_params = permitted_admin
    settings = (admin_params["settings"] || {}).slice(*ALLOWED_SETTING_FIELDS)

    validate_user_payload!(admin_params, settings, "admin")
    validate_unique_role_email!(User.admins, admin_params)

    admin.assign_attributes(admin_params.except("id", "settings"))
    admin.save!
    apply_user_settings!(admin, settings)

    Webhooks.trigger(Webhooks::ADMIN_SAVE, EaRows.admin_row(admin))
    render json: { success: true, id: admin.id }
  end

  def picture_record = User.admins.find(params[:id])

  def picture_permission_resource = :users
end
